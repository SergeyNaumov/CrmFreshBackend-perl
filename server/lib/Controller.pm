package Controller;
no warnings 'experimental::smartmatch';
use strict;
use utf8;
use Data::Dumper;
use Digest::SHA qw(sha256_hex);
use CRM;
#use lib './lib/CRM';
use CRM::Download;
use CRM::Session;
use CRM::AdminTree;
use CRM::Multiconnect;
use CRM::Password;
use CRM::Wysiwyg;
use CRM::Autocomplete;
use CRM::Ajax;
use CRM::Events;
use CRM::Const;

#use CRM::FontAwesome;
my $redirect='';
# Документация по CRM
# https://docs.google.com/document/d/15HZe0FP7uXhwViaC6QQ3FL-45rinyH1Z9ApiItfp7S8/edit#heading=h.u72z2f6wm8ll
sub new{
  {
    layout=>'index.html',
    template_folder=>'',
    TMPL_VARS=>{ # переменные шаблона по умолчанию
      #TEMPLATE_FOLDER=>'./templates/desktop',
      view_folder=>'./views',
      #layout=>'index.html',
    },
    rules=>[
      {
        url=>'.*',
        code=>sub{
          my $s=shift;
          $s->{login}=undef;
          #push @{$s->{APP}->{HEADERS}},['Access-Control-Allow-Origin','*'];
          $s->{db_r}=$s->{connects}->{crm_read};
          $s->{db}=$s->{connects}->{crm_write};
        }
      },
      { # закрываем сессию
        url=>'^\/logout',
        code=>sub{
          my $s=shift;
          CRM::Session::logout('s'=>$s,connect=>$s->{db});
          $s->print_json({success=>1})->end;
        }        
      },
      { # авторизация
        url=>'^\/login',
        code=>sub{
          my $s=shift;
          my $R=$s->request_content(from_json=>1);
          my $request={success=>0};
          if($R){
              $request=CRM::Session::create(
                's'=>$s,
                connect=>$s->{db},
                session_table=>'session',
                auth_table=>'manager',
                auth_id_field=>'id',
                auth_log_field=>'login',
                auth_pas_field=>'password',
                login=>"$R->{login}",
                password=>"$R->{password}",
                ip=>"$s->{vars}->{env}->{HTTP_X_REAL_IP}",
                encrypt_method=>'mysql_encrypt',

                # ограничения по логину
                max_fails_login=>3, # 3 неудачных попытки залогиниться под логином
                max_fails_login_interval=>3600, # за 3600 секунд (час)
                # ограничения по ip
                max_fails_ip=>20,
                max_fails_ip_interval=>3600
            );
            
            if(ref($request) ne 'HASH'){ # если это не хэш -- значит это ошибка
              $request={success=>0,errors=>[$request]};
            }
          }
          $s->print_json($request)->end;
        }
      },
      { # проверка авторизации
        url=>'^.*$',
        code=>sub{
          my $s=shift;
          
          my $result=CRM::Session::start('s'=>$s,connect=>$s->{db},encrypt_method=>'mysql_encrypt');


          my $login;
          $login=$s->{login}=$result->{login};
          if(`hostname` =~m{^(sv-home|sv-digital)}){ # для локальной отладки пароль не проверяем
            $s->{login}='admin'; 
          }

          unless($s->{login}){
            $s->print_json({
              success=>$login?1:0,
              login=>$login,
              errors=>$result->{errors},
              redirect=>'/login'
            })->end;
          }
          
        }
      },

      {
        url=>'^\/startpage$',
        code=>sub{
          my $s=shift;
          $s->print(CRM::get_startpage('s'=>$s))->end;
          #print Dumper()
        }
      },
      {
        url=>'/get-events',
        code=>sub{
          CRM::Events::process(shift);
        }
      },
      { # список фильтров для admin_table
        url=>'^\/get-filters\/(.+)$',
        code=>sub{
          my $s=shift; CRM::get_filters($s,$1);
        }
      },
      {
        url=>'^\/get-result$',
        code=>sub{
          my $s=shift;
          CRM::get_result($s);
        }
      },
      { # удаление элемента
        url=>'^\/delete-element\/([^\/]+)\/(\d+)$',
        code=>sub{
          my $s=shift;
          CRM::delete_element('s'=>$s,config=>$1,id=>$2,action=>'', script=>'delete_element');

        }
      },
      { # данные для скрипта edit_form
        url=>'^\/edit-form/([^\/]+)(\/(\d+))?$',
        code=>sub{
          my $s=shift;
          my $R=$s->request_content(from_json=>1);
          my $id=$3;
          my %arg=('s'=>$s,config=>$1,id=>"$id",action=>($id?'edit':'new'), script=>'edit_form');
          
          if($R){
              $arg{action}=$R->{action} if($R->{action});
              $arg{values}=$R->{values} if($R->{values});
          }
          #print "a: $arg{action}\n";
          CRM::processEditForm(%arg)
        }
      },

      # tree
      {
        url=>'^/admin-tree\/(.+)$',
        code=>sub{
          my $s=shift; my $config=$1;
          CRM::AdminTree::init('s'=>$s,config=>$config,script=>'admin_tree');
        }
      },
      { # получить memo
        url=>'^\/memo\/get\/([^\/]+)\/([^\/]+)\/(\d+)$',
        code=>sub{

          my $s=shift; my $config=$1;
          my $field_name=$2;
          my $id=$3;
          CRM::process_memo('s'=>$s,config=>$config,field_name=>$field_name,id=>$id,script=>'memo',action=>'get');
        }
      },
      { # добавить комментарий в memo
        url=>'^\/memo\/add\/([^\/]+)\/([^\/]+)\/(\d+)$',
        code=>sub{
          my $s=shift; my $config=$1;
          my $field_name=$2;
          my $id=$3;
          
          CRM::process_memo('s'=>$s,config=>$config,field_name=>$field_name,id=>$id,script=>'memo',action=>'add');
        }
      },
      { # update записи из memo
        url=>'^\/memo\/update\/([^\/]+)\/([^\/]+)\/(\d+)\/(\d+)$',
        code=>sub{
          my $s=shift; my ($config,$field_name,$id,$memo_id)=($1,$2,$3,$4);
          CRM::process_memo('s'=>$s,
            config=>$config,field_name=>$field_name,id=>$id,script=>'memo',memo_id=>$memo_id,action=>'update'
          );
        }
      },
      { # Удаление записи из memo
        url=>'^\/memo\/delete\/([^\/]+)\/([^\/]+)\/(\d+)\/(\d+)$',
        code=>sub{
          my $s=shift; my ($config,$field_name,$id,$memo_id)=($1,$2,$3,$4);
          CRM::process_memo('s'=>$s,
            config=>$config,field_name=>$field_name,id=>$id,script=>'memo',memo_id=>$memo_id,action=>'delete'
          );
        }
      },

      # -------------------
      #    1_TO_M
      # -------------------
      {
        url=>'^\/1_to_m\/insert\/([^\/]+)\/([^\/]+)\/(\d+)$',
        code=>sub{
          my $s=shift;
          my ($config,$field_name,$id)=($1,$2,$3);
          CRM::process_1_to_m(
            's'=>$s,action=>'insert',config=>$config,field_name=>$field_name,id=>$id,
            script=>'1_to_m'
          );
        }
      },
      # {
      #   url=>'(.*)',
      #   code=>sub{
      #     my $s=shift;
      #     $s->pre($1);
      #   }
      # },
      { # 1_to_m: update,delete,upload_file, delete_file
        url=>'^\/1_to_m\/(update|delete)\/([^\/]+)\/([^\/]+)\/(\d+)\/(\d+)$',
        code=>sub{
          my $s=shift;
          my ($action,$config,$field_name,$id,$one_to_m_id)=($1,$2,$3,$4,$5);
          #print "action: $action\n";
          CRM::process_1_to_m(
            's'=>$s,action=>$action,config=>$config,field_name=>$field_name,id=>$id,
            one_to_m_id=>$one_to_m_id,
            script=>'1_to_m'
          );
        }
      },
      { # 1_to_m: update,delete,upload_file, delete_file
        url=>'^\/1_to_m\/(upload_file|delete_file)\/([^\/]+)\/([^\/]+)\/([^\/]+)\/(\d+)\/(\d+)$',
        code=>sub{
          my $s=shift;
          my ($action,$config,$field_name,$child_field_name,$id,$one_to_m_id)=($1,$2,$3,$4,$5,$6);
          #print "action: $action\n";
          CRM::process_1_to_m(
            's'=>$s,action=>$action,
            config=>$config,
            field_name=>$field_name,
            child_field_name=>$child_field_name,
            id=>$id,
            one_to_m_id=>$one_to_m_id,
            script=>'1_to_m'
          );
        }
      },
      { # загрузка файлов без указания one_to_m_id.
        # (используется при multiload-е)
        url=>'^\/1_to_m\/upload_file\/([^\/]+)\/([^\/]+)\/([^\/]+)\/(\d+)$',
        code=>sub{
          my $s=shift;
          my ($config,$field_name,$child_field_name,$id)=($1,$2,$3,$4);
          CRM::process_1_to_m(
            's'=>$s,action=>'upload_file',
            config=>$config,
            field_name=>$field_name,
            child_field_name=>$child_field_name,
            id=>$id,
            script=>'1_to_m'
          );
        }
      },
      # -------------------
      # 1_to_m: download_file
      {
        url=>'^\/1_to_m\/download\/([^\/]+)\/([^\/]+)\/([^\/]+)\/(\d+)\/(\d+)(\/.+)?$',
        code=>sub{
          my $s=shift;
          
          CRM::Download::process(
            's'=>$s,
            config=>$1,
            field_name=>$2,
            script=>'download',
            child_field_name=>$3,
            id=>$4,
            one_to_m_id=>$5
          );
        }
      },
      { # обновление поля в 1_to_m
        # http://dev-crm.test/backend/1_to_m/update_field/user/contacts/username/86338
        url=>'^\/1_to_m\/update_field\/([^\/]+)\/([^\/]+)\/([^\/]+)\/(\d+)$',
        code=>sub{
          my $s=shift;
          CRM::process_1_to_m(
            's'=>$s,
            script=>'1_to_m',
            action=>'update_field',
            config=>$1,
            field_name=>$2,
            child_field_name=>$3,
            id=>$4
            
            
          );
        }

      },
      # 1_to_m: sort
      {
        url=>'^\/1_to_m\/sort\/([^\/]+)\/([^\/]+)\/(\d+)$',
        code=>sub{
          my $s=shift;
          
          CRM::process_1_to_m(
            's'=>$s,
            config=>$1,action=>'sort',
            field_name=>$2,
            script=>'1_to_m',
            id=>$3
          );
        }
      },
      # multiconnect:
      {
        url=>'^\/multiconnect\/([^\/]+)\/([^\/]+)$',
        code=>sub{
          my $s=shift;
          my ($config,$field_name)=($1,$2);
          CRM::Multiconnect::process(
            's'=>$s,
            config=>$1,
            script=>'multiconnect',
            field_name=>$2,
          );
        }
      },
      # password (работа с паролем)
      { 
        url=>'^\/password\/([^\/]+)\/([^\/]+)\/(\d+)$',
        code=>sub{
          my $s=shift;
          CRM::Password::process(
            's'=>$s,
            config=>$1,
            field_name=>$2,
            id=>$3,
            script=>'password',
          );
        }
      },
      {
        # 
        url=>'^\/wysiwyg\/([^\/]+)\/([^\/]+)(\/(\d+))?(\/([^\/]+))?',
        code=>sub{

          my $s=shift;


          
          CRM::Wysiwyg::process(
            's'=>$s,
            config=>$1,
            field_name=>$2,
            id=>$4?$4:undef,
            action=>$6?$6:'',
            script=>'wysiwyg',
          );
        }

      },
      {
        url=>'^\/autocomplete\/([^\/]+)',
        code=>sub{
          my $s=shift;
          CRM::Autocomplete::process('s'=>$s,script=>'autocomplete',config=>$1);
          $s->end;
        }
      },
      # Константы
      {
        url=>'^\/const\/get$',
        code=>sub{ # список констант системы
          my $s=shift;
          CRM::Const::get(
            's'=>$s,script=>'const',
          );
        }
      },
      {
        url=>'^\/const\/save_value$',
        code=>sub{ # список констант системы
          my $s=shift;
          CRM::Const::save_value(
            's'=>$s,script=>'const',
          );
        }
      },
      # / константы
      {
        url=>'^\/ajax\/([^\/]+)\/([^\/]+)$',
        code=>sub{
          my $s=shift;
          CRM::Ajax::process('s'=>$s,config=>$1,name=>$2)
        }
      },
      # parser excel
      {
        url=>'^\/parser-excel\/([^\/]+)$',
        code=>sub{
          my $s=shift;
          require CRM::ParserExcel;
          CRM::ParserExcel::process('s'=>$s,config=>$1);
        }
      },
      # /parser excel
      {
        url=>'^(.+)$',
        code=>sub{

          my $s=shift;
          $s->print("unknown url: $1")->end;
        }
      }
      # { # 1_to_m: delete
      #   url=>'^\/1_to_m\/delete\/([^\/]+)\/([^\/]+)\/(\d+)\/(\d+)$',
      #   code=>sub{
      #     my $s=shift;
      #     my ($config,$field_name,$id,$one_to_m_id)=($1,$2,$3,$4);
      #     CRM::process_1_to_m(
      #       's'=>$s,action=>'delete',config=>$config,field_name=>$field_name,id=>$id,
      #       one_to_m_id=>$one_to_m_id,
      #       script=>'1_to_m'
      #     );
      #   }
      # },
      # { # 1_to_m: upload file
      #   url=>'^\/1_to_m\/upload\/([^\/]+)\/([^\/]+)\/(\d+)\/(\d+)$',
      #   code=>sub{
      #     my $s=shift;
      #     my ($config,$field_name,$id,$one_to_m_id)=($1,$2,$3,$4);
      #     CRM::process_1_to_m(
      #       's'=>$s,action=>'delete',config=>$config,field_name=>$field_name,id=>$id,
      #       one_to_m_id=>$one_to_m_id,
      #       script=>'1_to_m'
      #     );
      #   }
      # }
      # { # /get/user/10226
      #   url=>'^\/get\/(.+?)\/(\d+)$',
      #   code=>sub{
      #     my $s=shift;
      #     my $config=$1; my $id=shift;
      #     my $form=CRM::init($config);
      #     CRM::Save($form);
      #   }
      # }

    ]
  };
}


return 1;
