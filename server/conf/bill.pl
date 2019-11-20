# use core_strateg;
# use field_operations;
use Data::Dumper;
my $ACTS={};
my $AV_FACT={};
$form={
    title => 'Счета',
    work_table => 'bill',
    work_table_id => 'id',
    make_delete => 0,
    read_only=>1,
    not_create=>1,
    GROUP_BY=>'wt.id',
    default_find_filter => 'header',
    tree_use => '0',
    explain=>1,
    events=>{
        permissions=>sub{
            if(param('f_user_id')){
              my $user_id=param('f_user_id');
              if($user_id=~m{^\d+$}){
                $form->{add_where}='dp.user_id='.$user_id
              }
            }
            if($form->{script}!~m{admin_table|find_objects}){
              field_operations:remove_form_field(form=>$form,name=>'docs');
            }
            if($form->{manager}->{permissions}->{admin_paids} || $form->{manager}->{login} eq 'admin'){
              $form->{read_only}=0; $form->{make_delete}=1;
            }
            if(
                $form->{manager}->{permissions}->{view_all_paids} || 
                $form->{manager}->{permissions}->{admin_paids} || 
                $form->{manager}->{login} eq 'admin')
            { # разрешаем видеть все платежи

            }
            else{
              $form->{make_delete}=0;
              foreach my $f (@{$form->{fields}}){
                $f->{read_only}=1 if($f->{name} ne 'acts');
              }

              if(scalar(@{$form->{manager}->{owner_groups}})){
                $form->{add_where}='mg.id IN ('.join(',',@{$form->{manager}->{owner_groups}}).')';
              }
              else{
                $form->{add_where}='m.id='.$form->{manager}->{id}
              }
            }

            if($form->{id}){
              my $sth=$form->{dbh}->prepare(q{
                  SELECT
                    wt.*,u.firm, u.id user_id,
                    t.header tarif, t.id tarif_id,
                    ul.with_nds,
                    ul.without_nds_dat, dp.ur_lico_id, ul.firm ur_lico,
                    m.id m_id, m.email m_email, m.group_id m_group_id, mg.path m_group_path, u.company_role,
                    af.number avance_fact_number
                  FROM 
                    bill wt 
                    left join manager m ON (m.id=wt.manager_id)
                    left join manager_group mg ON (m.group_id=mg.id)
                    join docpack dp ON (wt.docpack_id=dp.id)
                    LEFT JOIN ur_lico ul ON (dp.ur_lico_id=ul.id)
                    LEFT JOIN tarif t ON (dp.tarif_id=t.id)
                    JOIN user u ON (u.id=dp.user_id)
                    LEFT JOIN avance_fact af ON (af.bill_id=wt.id)
                  WHERE wt.id=?

              });
              $sth->execute($form->{id});
              $form->{old_values}=$sth->fetchrow_hashref;
              
            }

            if($form->{action} eq 'create_requsits' && $form->{old_values}->{user_id}){
              #print_header();
              $form->{dbh}->do("INSERT IGNORE INTO buhgalter_card(id) values($form->{old_values}->{user_id})");
              $form->{dbh}->do(qq{
                INSERT INTO 
                  buhgalter_card_requisits(user_id,firm,address,ur_address,inn,kpp,ogrn,rs,ks,bik,bank,position_otv,fio_dir,fio_dir_rod,position_otv_rod,gen_dir_f_in)
                SELECT id,firm,address,ur_address,inn,kpp,ogrn,rs,ks,bik,bank,position_otv,fio_dir,fio_dir_rod,position_otv_rod,gen_dir_f_in from user
                WHERE id=$form->{old_values}->{user_id}

              });
              print "Location: //edit_form.pl?config=$form->{config}&action=edit&id=$form->{id}\n\n";
              exit;
            }
            # 

        },
        before_search=>sub{
          my %arg=@_;
          return;
          #Dumper({args=>\%arg});
          my $qs=$form->{query_search};
          my $where=($arg{where}?"WHERE $arg{where}":'');
          my $query=qq{
              SELECT
                sum(s)
              FROM (
                  SELECT
                    wt.summ s
                  FROM
                    $arg{tables}
                  $where GROUP BY wt.id
              ) x
          };
          #my $sth=$form->{dbh}->prepare($query);
          #$sth->execute();
          #my $s=$sth->fetchrow();
          my $s=$form->{db}->query(query=>$query,onevalue=>1,errors=>$form->{errors});
          push @{$form->{out_before_search}},qq{Сумма: $s};
          #if(param('order_sum')){
          my @h=();  

          push @{$qs->{SELECT_FIELDS}},'wt.summ-sum(bp.sum) residue';
          #push @{$form->{log}}, $form->{query_search}->{SELECT_FIELDS};
         # print Dumper($form->{query_search}->{SELECT_FIELDS});
          
          my ($low,$hi);
          if(exists($qs->{sum})){
            ($low,$hi)=($qs->{sum}->[0],$qs->{sum}->[1]);
          }
          
          
          
          #push @h,"residue>=$low" if($low=~m/^\d+$/);
          #push @h,"residue<=$hi" if($hi=~m/^\d+$/);
          if(scalar(@h)){
            $qs->{HAVING}=\@h;
          }

        

      
    },
    before_update=>sub{
      $form->{dbh}->begin_work;
      $form->{dbh}->{AutoCommit}=0;
      if($form->{new_values}->{paid_date}!~m{[1-9]} && $form->{new_values}->{paid} && !$form->{old_values}->{paid}){
        push @{$form->{errors}},q{При оплате счёта необходимо указать дату оплаты};
      }

      if($form->{new_values}->{paid} && !$form->{old_values}->{paid}){
        # ставится галка "оплачено", создаём авансовую счёт-фактура
        
        my $company_role=($form->{old_values}->{company_role}==2)?'З':'П';
        my $sth=$form->{dbh}->prepare("SELECT ?, max(number_today) FROM avance_fact where paid_date=?");
        $sth->execute($form->{new_values}->{paid_date},$form->{new_values}->{paid_date});
        my ($dat,$number_today)=$sth->fetchrow();
        $number_today++;

        my $number=qq{$company_role}.'-'.sprintf("%03d",$number_today).'/'.$dat;

        my $sth=$form->{dbh}->prepare("REPLACE INTO avance_fact(bill_id,paid_date,number_today,number) values(?,?,?,?)");
        $sth->execute($form->{id},$form->{new_values}->{paid_date},$number_today,$number);
      }
      elsif(!$form->{new_values}->{paid} && $form->{old_values}->{paid}){
        $form->{dbh}->do("DELETE FROM avance_fact where bill_id=$form->{id}");
      }

      $form->{dbh}->commit;
      $form->{dbh}->{AutoCommit}=1;
    },
    after_search=>sub{
      my $list=shift;
      if(param('order_docs')){
          my @ids=map {$_->{wt__id}} @{$list};

          if(scalar(@ids)){
            my $sth=$form->{dbh}->prepare('SELECT bill_id,number,registered from act where bill_id IN ('.join(',',@ids).')' );
            $sth->execute();
            
            foreach my $a ( @{$sth->fetchall_arrayref({})}){
              push @{$ACTS->{$a->{bill_id}}},$a;
            }
            #pre('SELECT * FROM avance_fact WHERE bill_id IN ('.join(',',@ids).')');
            my $sth=$form->{dbh}->prepare('SELECT * FROM avance_fact WHERE bill_id IN ('.join(',',@ids).')');
            $sth->execute();
            foreach my $a ( @{$sth->fetchall_arrayref({})}){
              $AV_FACT->{$a->{bill_id}}=$a
            }
            
          }
      }
      #pre($list);
    }
    },
  run=>{
    get_more=>sub{
      my $id=shift;
      #my $sth=$form->{dbh}->prepare('SELECT * from act where bill_id=?');
      #$sth->execute($id);
      #my $list=$sth->fetchall_arrayref({});
      #pre($form->{acts}); exit;
      #print 'XX'; exit;
      #pre $ACTS;
      return template({
        template=>'./conf/bill.conf/bill_docs.tmpl',
        vars=>{
          act_list=>$ACTS->{$id},
          av_fact=>$AV_FACT->{$id}
        }
      });
    }
  },
  QUERY_SEARCH_TABLES=>
  [
      {table=>'bill',alias=>'wt',},
      {table=>'manager',alias=>'m',link=>'m.id=wt.manager_id',left_join=>1},
      {table=>'manager_group',alias=>'mg',link=>'m.group_id=mg.id',left_join=>1},
      {table=>'docpack',alias=>'dp',link=>'wt.docpack_id=dp.id'},
      {table=>'dogovor',alias=>'d',link=>'dp.id=d.docpack_id',for_fields=>['d_number']},
      {table=>'ur_lico',alias=>'ul',link=>'ul.id=dp.ur_lico_id',left_join=>1,for_fields=>['ur_lico_id']},
      {table=>'user',alias=>'u',link=>'dp.user_id=u.id'},
      {table=>'buhgalter_card_requisits',alias=>'bcr',link=>'bcr.id=wt.requisits_id',left_join=>1,for_fields=>['requisits_id']},
      {table=>'bill_part', alias=>'bp', link=>'bp.bill_id=wt.id', left_join=>1}
  ],
  plugins => [
      'find::to_xls'
  ],
    fields =>
    [
    {
            description=>'Остаток в детализации',
            name=>'sum',
            type=>'filter_extend_select_from_table',
            table=>'bill_part',
            tablename=>'bp',
            header_field=>'sum',
            filter_type=>'range',
            not_process=>1,
            filter_code=>sub{
                my $s=$_[0]->{str};
                return $s->{residue}
            }
            # before_search=>sub{
                # $form->{HAVING}='residue>1';
            # }
    },
    {
      description=>'Реквизиты <small>(ИНН, Наименование)</small>',
      type=>'select_from_table',
      table=>'buhgalter_card_requisits',
      name=>'requisits_id',
      header_field=>q{firm}, # 
      value_field=>'id',
      #regexp=>'^\d+$',
      filter_on=>1,
      regexp=>'^\d+$',
      autocomplete=>1,
      before_code=>sub{
        my $e=shift;
        if($form->{script}=~m{auto_complete}){
          $e->{out_header}=q{concat(inn,': ',firm)},
        }
        if($form->{old_values}->{user_id}){
          $e->{autocomplete}=0;
          $e->{sql}.=' WHERE user_id='.$form->{old_values}->{user_id};
        }
      },
      filter_code=>sub{
        my $s=$_[0]->{str};
        my $out='';
        if($s->{bcr__inn}){
          $out=qq{$s->{bcr__inn}:}
        }
        $out.=' '.$s->{bcr__firm};
        return $out;
      },
      code=>sub{
        my $e=shift;
        $e->{field}.=qq{<br><a href="?config=$form->{config}&id=$form->{id}&action=create_requsits">создать на основании реквизитов в основной карте</a><hr>}
      },
      sql=>q{SELECT id,if(inn<>'',concat(inn,': ',firm),firm) header from buhgalter_card_requisits}
    },
    {
      description=>'Юр.Лицо',
      name=>'c_ur_lico_id',
      type=>'code',
      code=>sub{
        return qq{<a href="./edit_form.pl?config=ur_lico&action=edit&id=$form->{old_values}->{ur_lico_id}">$form->{old_values}->{ur_lico}</a>}
      }
    },
    {
      description=>'Название компании',
      name=>'firm',
      type=>'filter_extend_text',
      tablename=>'u',
      filter_on=>1,
      filter_code=>sub{
        my $s=$_[0]->{str};
        my $out=qq{<a href="./edit_form.pl?config=user&action=edit&id=$s->{u__id}" target="_blank">$s->{u__firm}</a>};
        #if(){
        $out.=qq{
            <div style="margin-top: 10px; margin-bottom: 10px;"><a href="/tools/paid_division_parts.pl?bill_id=$s->{wt__id}" target="_blank">разделения</a></div>
          };
        #}
        return $out;
        
      }
    },
    # { # поиск по ID компании (из карты клиента)
    #   description=>'Наименование в карте',
    #   name=>'f_user_id',
    #   type=>'filter_extend_select_from_table',
    #   table=>'user',
    #   header_field=>'firm',
    #   tablename=>'u',
    #   value_field=>'id',
    #   db_name=>'id',
    #   autocomplete=>1,
    #   before_code=>sub{
    #     my $e=shift;
    #     if($form->{script} eq 'admin_table.pl'){
    #       #$e->{not_filter}=1;
    #     }
    #   }
    # },

    {
      description=>'Оплата на юрлицо',
      type=>'filter_extend_select_from_table',
      name=>'ur_lico_id',
      table=>'ur_lico',
      header_field=>'firm',
      value_field=>'id',
      tablename=>'ul',
      db_name=>'id'
    },
    {
      description=>'Детализация',
      name=>'more',
      type=>'code',
      code=>sub{

        return '' unless($form->{id});
        return qq{<a href="https://crm.strateg.ru/tools/paid_division_parts.pl?bill_id=$form->{id}" target="_blank">посмотреть</a>}
      }
    },
    {
      description=>'Компания',
      name=>'firm_c',
      type=>'code',
      code=>sub{
        return qq{<a href="./edit_form.pl?config=user&action=edit&id=$form->{old_values}->{user_id}" target="_blank">$form->{old_values}->{firm}</a>}
      }
    },
    {
      description=>'Тариф',
      type=>'code',
      name=>'tarif',
      code=>sub{
        return qq{<a href="./edit_form.pl?config=tarif&action=edit&id=$form->{old_values}->{tarif_id}" target="_blank">$form->{old_values}->{tarif}</a>}
      }
    },
    {
      description=>'Номер счёта',
      type=>'text',
      filter_on=>1,
      name=>'number',
      read_only=>1
    },
    {
      description=>'Номер договора',
      type=>'filter_extend_text',
      filter_on=>1,
      name=>'d_number',
      db_name=>'number',
      tablename=>'d',
      read_only=>1
    },
    {
      description=>'Номер платёжного поручения',
      type=>'text',
      name=>'payment_order',
    },
    {
      description=>'Наименование услуги',
      type=>'text',
      name=>'service_name'
    },
    {
      description=>'Сумма',
      type=>'text',
      filter_type=>'range',
      filter_on=>1,
      name=>'summ'
    },
    {
      description=>'Комментарий',
      type=>'textarea',
      filter_on=>1,
      name=>'comment'
    },
    {
      description=>'Дата выставления',
      type=>'date',
      name=>'registered',
      filter_on=>1,
      default_off=>1
    },
    {
      description=>'Оплата производилась',
      type=>'checkbox',
      name=>'paid',
      after_save=>sub{
        my $e=shift;
        my %to=();
        #pre($form->{manager});
        #pre([
        #  $form->{old_values}->{m_id},
        #  $form->{old_values}->{m_email},
        #]);
        my $ov=$form->{old_values};
        
        my $own=core_strateg::get_owner(
          cur_manager=>{
            id=>$ov->{m_id},
            group_path=>$ov->{m_group_path},
            group_id=>$ov->{m_group_id},
          },
          connect=>$form->{dbh}
        );
        
        if(!$ov->{paid} && $e->{value}){
          if($ov->{m_email} && $ov->{m_id}!=$form->{manager}->{id}){
            $to{$ov->{m_email}}=1
          }
          if($own->{email} && $own->{id}!=$form->{manager}->{id}){
            $to{$own->{email}}=1
          }
          my $to_str=join(',',keys(%to));
          if($to_str){
              $form->{self}->send_mes({
                to=>$to_str,
                subject=>qq{$ov->{firm} Счёт №$ov->{number} оплачен},
                message=>qq{
                  Для компании <a href="http://$ENV{HTTP_HOST}/edit_form.pl?config=user&action=edit&id=$ov->{user_id}">$ov->{firm}</a><br>
                  <a href="http://$ENV{HTTP_HOST}/edit_form.pl?config=bill&action=edit&id=$form->{id}">Счёт №$ov->{number}</a><br>
                  Сумма: $form->{new_values}->{summ}<br>
                  дата оплаты: $form->{new_values}->{paid_date}
                }
              })
          }
        }
      },
      code=>sub{
        my $e=shift;
        if($form->{old_values}->{avance_fact_number}){
          $e->{field}.=qq{
            <hr>
            <b>Авансовая счёт-фактура №$form->{old_values}->{avance_fact_number}</b><br>
            с печатями: <a href="/tools/load_document.pl?type=av_fact&bill_id=$form->{id}&format=doc">doc</a> | <a href="/tools/load_document.pl?type=av_fact&bill_id=$form->{id}&format=pdf">pdf</a><br>
            без печатей: <a href="/tools/load_document.pl?type=av_fact&bill_id=$form->{id}&format=doc&without_print=1">doc</a> | <a href="/tools/load_document.pl?type=av_fact&bill_id=$form->{id}&format=pdf&&without_print=1">pdf</a><br>
            <hr>
          }
        }
        return $e->{field};
      }
    },
    {
      description=>'Дата оплаты',
      type=>'date',
      name=>'paid_date',
      filter_on=>1,
      default_off=>1
    },

    {
      description=>'Оплачен до',
      type=>'date',
      name=>'paid_to',
      filter_on=>1,
      default_off=>1,
      code=>sub{
        my $e=shift; my $max;
        if(my $user_id=$form->{old_values}->{user_id}){
          my $sth=$form->{connects}->{strateg_read}->prepare(q{
          SELECT
            max(paid_to)
          FROM
            docpack dp
            join bill b ON (b.docpack_id=dp.id)
          WHERE
            dp.user_id=?
          });
          $sth->execute($user_id);
          $max=$sth->fetchrow;
          
        }
        if($max){
          $e->{field}.=qq{ <small>максимальная дата оплаты для данной компании: $max </small>}
        }
        return $e->{field};
      }
    },
    {
      description=>'Группа счёта',
      name=>'group_id',
      type=>'select_from_table',
      table=>'manager_group',
      tablename=>'mg',
      header_field=>'header',
      value_field=>'id',
      filter_on=>1,
    },
    {
      description=>'Менеджер счёта',
      name=>'manager_id',
      type=>'select_from_table',
      table=>'manager',
      tablename=>'m',
      header_field=>'name',
      value_field=>'id',
      filter_on=>1,
    },
    {
      description=>'Акты',
      name=>'act',
      type=>'1_to_m',
      table=>'act',
      table_id=>'id',
      foreign_key=>'bill_id',
      link_edit=>'./edit_form.pl?config=act&action=edit&id=<%id%>',
      not_create=>1,
      make_delete=>0,
      before_code=>sub{
        my $e=shift;
        $e->{make_delete}=1 if($form->{manager}->{permissions}->{admin_paids} || $form->{manager}->{login} eq 'admin');
        if(
            ($form->{manager}->{permissions}->{admin_paids} || $form->{manager}->{login} eq 'admin')
              ||
            $form->{old_values}->{paid}
              ||
            $form->{old_values}->{manager_id}==$form->{manager}->{id}
        ){
          $e->{not_create}=0;
          $e->{read_only}=0;
          $e->{link_add}=qq{./edit_form.pl?config=act&action=new&bill_id=$form->{id}};
          #pre('ok');
        }
        
      },
      fields=>[
        {
          description=>'Номер акта',type=>'text',name=>'number',
          slide_code=>sub{
            my $e=shift; my $v=shift;
            my $out=qq{
              <b>Акт:</b> $v->{number__value}<br>
              с печатями: <a href="/tools/load_document.pl?type=act&act_id=$v->{id}&format=doc">doc</a> | <a href="/tools/load_document.pl?type=act&act_id=$v->{id}&format=pdf">pdf</a><br>
              без печатей: <a href="/tools/load_document.pl?type=act&act_id=$v->{id}&format=doc&without_print=1">doc</a> | <a href="/tools/load_document.pl?type=act&act_id=$v->{id}&format=pdf&without_print=1">pdf</a>
            };
            my $without_nds_dat=$form->{old_values}->{without_nds_dat};
            $without_nds_dat=~s{[^\d]}{}g;
            my $registered=$v->{registered__value};
            $registered=~s{[^\d]}{}g;
            $without_nds_dat+=0;
            #pre({
            #  with_nds=>$form->{old_values}->{with_nds},
            #  without_nds_dat=>$without_nds_dat,
            #  registered=>$registered
            #});
            
            if($form->{old_values}->{with_nds} && (!$without_nds_dat || $registered<$without_nds_dat) ){
              $out.=qq{
                <hr>
                <b>Счёт-фактура:</b> $v->{number__value}<br>
                с печатями: <a href="/tools/load_document.pl?type=fact&act_id=$v->{id}&format=doc">doc</a> | <a href="/tools/load_document.pl?type=fact&act_id=$v->{id}&format=pdf">pdf</a><br>
                без печатей: <a href="/tools/load_document.pl?type=fact&act_id=$v->{id}&format=doc&without_print=1">doc</a> | <a href="/tools/load_document.pl?type=fact&act_id=$v->{id}&format=pdf&without_print=1">pdf</a><br>
              };
            }
            return $out;
            
          }
        },
        {description=>'Дата',name=>'registered',type=>'date',read_only=>1},
        {description=>'Сумма',name=>'summ',type=>'text'},

      ]
    },
    {
      description=>'Подробнее',
      name=>'docs',
      type=>'text',
      not_edit=>1,
      before_code=>sub{
        my $e=shift;
        if($form->{script} eq 'admin_table.pl'){
          delete($e->{not_process});
        }
      },
      not_process=>1,
      filter_code=>sub{
        my $s=$_[0]->{str};
        return &{$form->{run}->{get_more}}($s->{wt__id});
      },
      db_name=>'id'
    }
    ]
};
