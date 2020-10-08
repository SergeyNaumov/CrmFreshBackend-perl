package Controller;
no warnings 'experimental::smartmatch';
use strict;
use utf8;
use Data::Dumper;
use Digest::SHA qw(sha256_hex);
use CRM;

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
use CRM::Documentation;

# документы для конкретного проекта
use Controller::Doc;
use lib './lib/extend';


my $redirect='';
sub new{
  my $rules=[];
  my $rules_main=get_rules();

  push @{$rules},@{$rules_main};
  my $rules_doc=Controller::Doc::get();
  if(scalar(@{$rules_doc})){
    push @{$rules},@{$rules_doc};
  }
  
  push @{$rules},
  {
        url=>'^(.+)$',
        code=>sub{

          my $s=shift;
          $s->print("unknown url: $1")->end;
        }
  };
  
  return {
    layout=>'index.html',
    template_folder=>'',
    TMPL_VARS=>{ # переменные шаблона по умолчанию
      #TEMPLATE_FOLDER=>'./templates/desktop',
      view_folder=>'./views',
      #layout=>'index.html',
    },
    rules=>$rules
  };
}

sub get_rules{
    [
      {
        url=>'.*',
        code=>sub{
          my $s=shift;
          $s->{login}=undef;
          
          $s->{db_r}=$s->{connects}->{crm_read};
          $s->{db}=$s->{connects}->{crm_write};
          
          if($s->{config}->{use_project}){
            my $domain=$s->{vars}->{env}->{HTTP_HOST};
            $s->{project}=$s->{db_r}->query(
              query=>'SELECT p.* FROM project p  WHERE p.domain=?',
              values=>[$domain],
              onerow=>1
            );
            unless($s->{project}){
              $s->print_json({errors=>"домен $domain не найден!"})->end;
              return;
            }
            #print Dumper($s->{project});
          }

        }
      },
      {
        url=>'^\/logo\.(.*)$',
        code=>sub{
          my $s=shift;
          $s->{stream_out}=1;
          push @{$s->{APP}->{HEADERS}},("Content-Type","image/png");
          
          if($s->{config}->{use_project}){
            $s->{stream_file}='../logo.png'
          }
          else{
            $s->{stream_file}='../logo.png'
          }
          $s->end;
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
              if($s->{config}->{use_project}){
                    $request=CRM::Session::project_create(
                      's'=>$s,
                      connect=>$s->{db},
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
              }
              else{
                    $request=CRM::Session::create(
                      's'=>$s,
                      connect=>$s->{db},
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
              }

            
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
          
          my $result;
          $result=CRM::Session::start('s'=>$s,connect=>$s->{db},encrypt_method=>'mysql_encrypt');

          my $login;
          $login=$s->{login}=$result->{login};
          if(`hostname` =~m{^(sv-HP-EliteBook-2570p|sv-home|sv-digital)}){ # для локальной отладки пароль не проверяем
            $s->{login}='admin'; 
            $s->{manager}={
              id=>1,
              login=>'admin'
            }
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
      { # mainpage
        url=>'^\/mainpage$',
        code=>sub{
          my $s=shift;
          my $curdate=CRM::cur_date();
          if($curdate=~m/^(\d{4})-(\d{2})-(\d{2})$/){
            $curdate="$3.$2.$1"
          }
          if($s->{project}){
              $s->print_json({
                curdate=>$curdate,
                manager=>$s->{db}->query(
                  query=>'SELECT id,login,name,position, concat("/edit-form/project_manager/",id) link from project_manager where project_id=? and id=?',
                  values=>[$s->{project}->{id},$s->{manager}->{id}],
                  onerow=>1,
                ),
                news_list=>$s->{db}->query(
                  query=>q{SELECT header,DATE_FORMAT(a.registered, '%e.%m.%y') registered,body from project_crm_news WHERE project_id=? order by registered desc limit 5},
                  values=>[$s->{project}->{id}]
                )
              })
          }
          else{
              
              $s->print_json(
                {
                  curdate=>$curdate,
                  news_list=>$s->{db}->query(
                    query=>q{SELECT header,DATE_FORMAT(registered, '%e.%m.%y') registered, body from crm_news order by registered desc limit 5},
                  ),
                  manager=>$s->{db}->query(
                query=>'SELECT id,login,name,position, concat("/edit-form/manager/",id) link from manager where id=?',
                    values=>[$s->{manager}->{id}],
                    onerow=>1,
                  ),
                }
              )
          }
          $s->end;

        }
      },
      { 
        url=>'/get-events',
        code=>sub{
          CRM::Events::process(shift);
        }
      },
      {
        url=>'^\/documentation\/([^\/]+)$',
        code=>sub{
          my $s=shift; my $config=$1;
          CRM::Documentation::go($s,$config);
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

      # ajax
      {
        url=>'^\/ajax\/([^\/]+)\/([^\/]+)$',
        code=>sub{
          my $s=shift;
          require CRM::Ajax;
          
          CRM::Ajax::process('s'=>$s,script=>'ajax',config=>$1,name=>$2)
        }
      },
      {
        url=>'^\/docpack\/([^\/]+)\/([^\/]+)$',
        code=>sub{
          my $s=shift;
          require CRM::Docpack;
          if(my $R=$s->request_content(from_json=>1)){
            my %arg=('s'=>$s,script=>'docpack',config=>$1,name=>$2,R=>$R, action=>$R->{action},id=>$R->{id});
            
            
            CRM::Docpack::process(%arg);
          }
          else{
            $s->print_json({success=>0,errors=>['параметры json отсутствуют']})
          }
          $s->end;

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
      # load_document (для документооборота)
      {
        url=>'^\/load_document(\/(.+))?$',
        code=>sub{
          my $s=shift;
          require CRM::LoadDocument;
          CRM::LoadDocument::process($s,$1);
          $s->end;
        }
      },
      # KLADR
      {
        url=>'^\/extend\/KLADR',
        code=>sub{
          my $s=shift;
          require extend::KLADR;
          extend::KLADR::go($s)
        }
      },
      # DADATA
      {
        url=>'^\/extend\/DADATA',
        code=>sub{
          my $s=shift;
          require extend::DADATA;
          extend::DADATA::go($s)
        }
      },
      {
        url=>'^(.+)$',
        code=>sub{

          my $s=shift;
          $s->print("unknown url: $1")->end;
        }
      }
    ]
}


return 1;
