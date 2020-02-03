#$ENV{REMOTE_USER}='admin' if($ENV{REMOTE_USER} eq 'admin');
use lib './lib';
use coresubs;

$form={
	title => 'Акты',
	work_table => 'act',
	work_table_id => 'id',
	make_delete => '1',
	
	#read_only => '1',
	make_delete=>0,
	not_create=>1,
	tree_use => '0',
  GROUP_BY=>'wt.id',
  javascript=>{
    include=>['./conf/user.conf/doubles.js'] # проверка на дубли
  },
  QUERY_SEARCH_TABLES=>
    [
      {table=>'act',alias=>'wt'},
      {table=>'manager',alias=>'m',left_join=>1,link=>'wt.manager_id=m.id',for_fields=>['manager_id']},
      {table=>'bill',alias=>'b',link=>'wt.bill_id=b.id',left_join=>1,for_fields=>['firm','bill_number']},
      {table=>'docpack',alias=>'dp',link=>'dp.id=b.docpack_id',left_join=>1,for_fields=>['firm','ul_firm']},
      
      {table=>'user',alias=>'u',link=>'dp.user_id=u.id',left_join=>1,for_fields=>['firm']},
      
      {table=>'ur_lico',alias=>'ul',link=>'ul.id=dp.ur_lico_id',left_join=>1,for_fields=>['ul_firm']},
    ],
    #explain=>1,
  run=>{
    refresh_act_number=>sub{ # перевыставить счёт
            my ($act_id,$new_registered)=@_;
          
            my $company_role=($form->{old_values}->{company_role}==2)?'З':'П';
            
            #$form->{dbh}->{AutoCommit}=0;
            
            $form->{dbh}->begin_work;
            #print "1";
            
            my $sth=$form->{dbh}->prepare(q{
              SELECT
                if(max(number_today),max(number_today)+1,1), DATE_FORMAT(?, '%e%m%y')
              FROM
                act
              WHERE registered=?
            });
            $sth->execute($new_registered,$new_registered);
            my ($number_today,$dat)=$sth->fetchrow();
            my $number;
            if($new_registered ge '2020-01-16'){
              #Названия теперь без дефиса, чтобы влезало в 1С
              $number=qq{$company_role}.sprintf("%03d",$number_today).'/'.$dat;
            }else{
              $number=qq{$company_role}.'-'.sprintf("%03d",$number_today).'/'.$dat;
            }

            $sth=$form->{dbh}->prepare("UPDATE act SET registered=?,number_today=?,number=? WHERE id=$act_id");
            $sth->execute($new_registered,$number_today,$number);
            $form->{dbh}->commit;
            $form->{dbh}->{AutoCommit}=1;
    },

    get_old_values=>sub{
      my $bill_id=param('bill_id');
      if($bill_id=~m{^\d+$}){
        my $sth=$form->{dbh}->prepare(q{
          SELECT
            u.company_role, b.id bill_id, b.summ bill_summ,
            b.paid bill_paid
          FROM
            bill b
            join docpack dp ON (dp.id=b.docpack_id)
            join user u ON (u.id=dp.user_id)
          where b.id=?
        });
        $sth->execute($bill_id);
        $form->{old_values}=$sth->fetchrow_hashref;
      }
    }
  },
	events=>{
		permissions=>[
      sub{ # доступ в карту
        if($form->{action} eq 'new'){
          &{$form->{run}->{get_old_values}}();
        }
        elsif($form->{action}=~m{^(edit|update)$} && $form->{id}) {
                
                my $sth=$form->{dbh}->prepare(q{
                  SELECT
                    b.paid bill_paid, act.*,u.firm,dp.user_id,
                    b.number bill_number
                  FROM
                    act
                    JOIN bill b ON (act.bill_id=b.id)
                    JOIN docpack dp ON (b.docpack_id=dp.id)
                    join user u ON (u.id=dp.user_id)
                  WHERE act.id=?
                });
                $sth->execute($form->{id});
                $form->{old_values}=$sth->fetchrow_hashref;
                
                if(!$form->{manager}->{permissions}->{admin_paids}){
                  $form->{read_only}=1;
                }
        }
      }
      
    ],
    before_update=>sub{

      if($form->{new_values}->{registered} ne $form->{old_values}->{registered}){
        &{$form->{run}->{refresh_act_number}}($form->{id},$form->{new_values}->{registered});
      }
    },
    after_save=>sub{
      $form->{old_values}->{user_id}=param('user_id') unless($form->{old_values}->{user_id});
      if($form->{action} eq 'insert'){
            
            $form->{dbh}->begin_work;
            my $sth=$form->{dbh}->prepare(q{
              SELECT
                if(max(number_today),max(number_today)+1,1), DATE_FORMAT(?, '%e%m%y')
              FROM
                act
              WHERE registered=?
            });
            $sth->execute($form->{new_values}->{registered},$form->{new_values}->{registered});
            my ($number_today,$dat)=$sth->fetchrow();
            &{$form->{run}->{get_old_values}};
            my $company_role=($form->{old_values}->{company_role}==2)?'З':'П';

            my $number;
            if($form->{new_values}->{registered} ge '2020-01-16'){
              #Названия теперь без дефиса, чтобы влезало в 1С
              $number=qq{$company_role}.sprintf("%03d",$number_today).'/'.$dat;
            }else{
              $number=qq{$company_role}.'-'.sprintf("%03d",$number_today).'/'.$dat;
            }
            
            $sth=$form->{dbh}->prepare("UPDATE act SET number_today=?,number=? WHERE id=$form->{id}");
            $sth->execute($number_today,$number);
            $form->{dbh}->commit;
            $form->{dbh}->{AutoCommit}=1;
      }

      if($form->{old_values}->{bill_id}){
        print qq{<script>var base=parent.opener; base.document.getElementById('1_to_m_act').innerHTML=base.loadDocAsync('/load_1_to_m.pl?config=bill&field=act&id=$form->{old_values}->{bill_id}');</script>};
      }
    },
    after_insert=>sub{
      #if(!$form->{manager}->{permissions}->{change_manager_all} && !scalar(@{$form->{manager}->{owner_groups}})){ # Если нет прав менять менеджера -- проставляем себя
      #  my $sth=$form->{dbh}->prepare("UPDATE $form->{work_table} set manager_id = ? where id = ?");
      #  $sth->execute($form->{manager}->{id},$form->{id});
      #}
    }
	},
  #explain=>1,
	fields=>[
        {
          name=>'bill_id',
          type=>'hidden',
          read_only=>1,
          before_code=>sub{
            my $e=shift;
            if($form->{action}=~m{^(new|insert)$}){
              $e->{read_only}=0;
              $e->{value}=param('bill_id');
            }
          }
        },
        {
          #description=>'Ссылки',
          type=>'code',
          name=>'links',
          code=>sub{
            if($form->{old_values}){
              return qq{
                <a href="./edit_form.pl?config=user&action=edit&id=$form->{old_values}->{user_id}" target="_blank">$form->{old_values}->{firm}</a><br>
                <a href="./edit_form.pl?config=bill&action=edit&id=$form->{old_values}->{bill_id}" target="_blank">Счёт №$form->{old_values}->{bill_number}</a>
              }
            }
          }
        },
        {
          description=>'Организация',
          type=>'filter_extend_text',
          tablename=>'u',
          name=>'firm',
          filter_on=>1,
          filter_code=>sub{
            my $s=$_[0]->{str};
            return qq{<a href="./edit_form.pl?config=user&action=edit&id=$s->{u__id}" target="_blank">$s->{u__firm}</a>}
          }
        },
        {
          description=>'Юр.лицо',
          name=>'ul_firm',
          type=>'filter_extend_select_from_table',
          sql=>q{select id,concat(firm,' ',comment) from ur_lico order by header},
          table=>'ur_lico',
          header_field=>'firm',
          value_field=>'id',
          tablename=>'ul'

        },
        {
          description=>'Номер акта',
          name=>'number',
          type=>'text',
          read_only=>1,
          filter_on=>1,
          code=>sub{
            my $e=shift;
            return '<u>будет назначен после создания</u>' if($form->{action} eq 'new');
            return $e->{value};
          }
        },
        {
          description=>'Номер счёта',
          name=>'bill_number',
          type=>'filter_extend_text',
          tablename=>'b',
          db_name=>'number',
          filter_on=>1,
          filter_code=>sub{
            my $s=$_[0]->{str};
            return
              qq{<a href="./edit_form.pl?config=bill&action=edit&id=$s->{b__id}" target="_blank">$s->{b__number}</a>}
          }

        },
        {
          description=>'Дата акта',
          name=>'registered',
          #read_only=>1,
          type=>'date',
          filter_on=>1,
          regexp=>'^20\d{2}-\d{2}-\d{2}',
          default_off=>1,
          code=>sub{
            my $e=shift;
            return
              $e->{field}.=qq{<br><span style="color: red;"><b>Внимание!</b></span> при изменении даты акта поменяется его номер!<br><br>}
          }
          # before_code=>sub{
          #   my $e=shift;
          #   if($form->{action}=~m{^(new|insert)}){
          #     $e->{read_only}=0; 
          #     $e->{value}=coresubs::cur_date() if($form->{action} eq 'insert');

          #   }
          # },
        },
		{
			description=>'Комментарий',
			name=>'comment',
			type=>'code',
			code=>sub{
				my $sth=$form->{dbh}->prepare("SELECT comment FROM bill where id=?");
				$sth->execute($form->{old_values}->{bill_id});
				$sth=$sth->fetchrow();
				return "$sth";
			}
		},
        {
          description=>'Сумма',
          name=>'summ',
          regexp=>'^\d+(\.\d+)?$',
          filter_on=>1,
          before_code=>sub{
            my $e=shift;
            $e->{value}=$form->{old_values}->{bill_summ} if($form->{action} eq 'new');
          },
          replace=>[
            [',','.'],
            ['[^\.\d]',''],
          ],

        },
        {
          description=>'Создал',
          type=>'select_from_table',
          name=>'manager_id',
          table=>'manager',
          tablename=>'m',
          header_field=>'name',
          value_field=>'id',
          read_only=>1,
          filter_on=>1,
          before_code=>sub{
            my $e=shift;
            if($form->{action}=~m{^(new|insert)$}){
              $e->{value}=$form->{manager}->{id};
            }
            $e->{read_only}=0 if($form->{action} eq 'insert')
          },

        }
      
	]
};
