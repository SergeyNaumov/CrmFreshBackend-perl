# 1. Проверить, почему не disable-тся форма при наличии хотя бы одного не валидного получится
# 2. проверять regexp_rules на стороне сервер
# 3. проверять regexp_rules на стороне клиента (select_from_table)

$form={
	title => 'Выполненные работы по выездной поверке',
	work_table => 'work',
	work_table_id => 'id',
	make_delete => '0',
  not_create=>1,
  width=>'800',
	tree_use => '0',
  #explain=>1,
  GROUP_BY=>'wt.id',
  run=>[%INCLUDE './conf/work.conf/run.pl'%],
  perpage=>300,
	events=>{
		permissions=>[%INCLUDE './conf/work.conf/permissions.pl'%],
    before_save=>sub{
        my $V=$form->{R}->{values};
        if(!$V->{reestr_si_modification_id} || $V->{reestr_si_modification_id}!~m/^\d+$/){
          push @{$form->{errors}},'Не выбрана модификация';
        }
        # Мне нужно добавить дополнительную защиту от дурака. Что нужно: если дата поверки одинаковая,
        # то заводские номера счетчиков не должны совпадать. То есть нельзя на один и тот же день,
        # зарегистрировать две поверки по одному и тому же счетчику
        if($V->{dat_pov}=~m/^\d+-\d+-\d+$/ && $V->{zav_num}){
          my $where_check="dat_pov=? and zav_num=?";
          if($form->{id}){
            $where_check.=" AND id<>$form->{id}"
          }
          my $exists=$form->{db}->query(
            query=>"SELECT id from work where $where_check",
            values=>[$V->{dat_pov},$V->{zav_num}],
            onevalue=>1
          );
          if($exists){
            push @{$form->{errors}},qq{В базе <a href="/edit_form/work/$exists" target="_blank">уже существует</a> поверка с датой $V->{dat_pov} и заводским номером: $V->{zav_num}};
          }
        }

        # при добавлении новой работы, лиюл изменении DU пересчитываем qmax

    },
    after_save=>sub{
      my $du=$form->{R}->{values}->{dn};
      my $ranges=$form->{ov}->{ranges};
      #print "after_save!\n";
      if(
          ($du==15 && ($ranges < 0.6 || $ranges > 1.0) ) || # ($ranges < 0.7 || $ranges > 1.1)
          ($du==20 && ($ranges < 0.7 || $ranges > 1.1) ) || # ($ranges < 0.9 || $ranges > 1.5)
          ($form->{R}->{values}->{dn} ne $form->{ov}->{dn})){
        if($du){
          my $ranges;
          # Для Ду15:
          # 0.3..1.1
          # Для Ду20:
          # 0.05..1.5
          
          # qMax -- то же значение, что и ranges

          if($du==15){
            $ranges=&{$form->{run}->{range}}(from=>0.6,to=>1.0,order=>1) # (from=>0.7,to=>1.1,order=>1)
          }
          elsif($du==20){
            $ranges=&{$form->{run}->{range}}(from=>0.7,to=>1.1,order=>1) # (from=>0.9,to=>1.5,order=>1)
          }
          #pre($ranges);
          # range(from=>21,to=>27,order=>1)
          if($ranges){
            
            $form->{db}->query(
              query=>'UPDATE work set ranges=? where id=?',
              values=>[$ranges,$form->{id}],
              
            )
            #push @{$form->{fields}},{name=>'qmax',type=>'hidden',value=>$qmax};
          }
        }
      }
    },
    before_search=>sub{
      my $SF=$form->{query_search}->{SELECT_FIELDS};
      #push @{$SF}, 'wt.num_label wt__num_label';
      # для модификаций
      push @{$SF},"group_concat(distinct modif.header SEPARATOR ', ') as modif_headers";
      # собираем условия по фильтру f_grsi_mod

      foreach my $filter (@{$form->{R}->{query}}){
        my ($name,$value)=($filter->[0],$filter->[1]);
        if($name eq 'f_grsi_mod' && $value){
          my @where_list;
          foreach my $v (@{$value}){
            if($v=~m/^r(\d+)(-(\d+))?$/){
              my ($grsi_num,$reestr_si_modification_id)=($1,$3);


              if($reestr_si_modification_id=~m/^\d+$/){
                push @where_list,"(wt.grsi_num=$grsi_num and wt.reestr_si_modification_id=$reestr_si_modification_id)"
              }
              elsif($grsi_num=~m/^\d+$/){
                push @where_list,"(wt.grsi_num=$grsi_num)"
              }
              
            }
            

          }
          push @{$form->{query_search}->{WHERE}},join(' OR ',@where_list)

        }
        
      }

      # выводим табоицу с отображением по количеству для каждого табельного номера эталона
      my $tables_str=join('',@{$form->{query_search}->{TABLES}});
      my $where_str='';
      if(scalar(@{$form->{query_search}->{WHERE}})){
        $where_str='WHERE '.join(' AND ',@{$form->{query_search}->{WHERE}});
      }
      my $etalon_query=qq{select tnumber, count(*) cnt from (SELECT tnumber FROM $tables_str $where_str  GROUP BY wt.id) x GROUP BY tnumber};
      #pre($etalon_query );

      my $etalon_list=$form->{db}->query(
        query=>$etalon_query
      );

      my $etalon_table=$s->template({
        template=>'./conf/work.conf/etalon_table.html',
        vars=>{
          LIST=>$etalon_list,
          dp=>$form->{query_search}->{on_filters_hash}->{dat_pov}
        }
      });
      push @{$form->{out_before_search}},$etalon_table;
    },
    after_search=>sub{
        my %arg=@_;
        my $not_ready=$form->{db}->query(query=>'select count(*) from tasks_protocols_pdf where ready=0',onevalue=>1);
        if($not_ready){
          push @{$form->{out_after_search}},'Невыполненых заданий: '.$not_ready;
        }
        else{
          my @ids=();
          if(scalar(@{$arg{result}})){
            @ids=map {$_->{wt__id}} @{$arg{result}}; 
          }
          
          
          if(scalar(@ids)){
            my $ids=join(',',@ids);
            my $protocols_arch_button=$s->template({
              template=>'./conf/work.conf/create_protocols_arch.html',
              vars=>{
                ids=>$ids,
                #dp=>$form->{query_search}->{on_filters_hash}->{dat_pov}
              }
            });
            push @{$form->{out_after_search}},$protocols_arch_button;
          }
        } 
    
    },

  },

  AJAX=>[%INCLUDE './conf/work.conf/AJAX.pl'%],
  QUERY_SEARCH_TABLES=>
  [
    {table=>'work',alias=>'wt'},
    {table=>'master',alias=>'m',link=>'wt.master_id=m.id',left_join=>1},
    {table=>'reestr_si',alias=>'rs',link=>'wt.grsi_num=rs.id',left_join=>1},
    {table=>'reestr_si_modification',alias=>'modif',link=>'wt.reestr_si_modification_id=modif.id',left_join=>1},
    {table=>'main_master',alias=>'mm',link=>'wt.main_master_id=mm.id',left_join=>1},
    #{table=>'master',alias=>'m',link=>'m.tnumber=wt.num_sv2',left_join=>1}
  ],
  on_filters=>[

      {name=>'dat_pov'},
      {name=>'num_sv2'},
      {name=>'num_sv1'},
      
      #{name=>'num_label'},
      {name=>'f_grsi_mod'},
      {name=>'type_wather'},
      {name=>'dn'},
      {name=>'zav_num'},
      {name=>'born_year'},
      {name=>'is_ok'},
      {name=>'dat_pov_next'},
      {name=>'address'}
  ],
  #search_on_load=>1,
  fields =>
  [
    {
      description=>'Ссылки',
      type=>'code',
      name=>'links',
      code=>sub{
        my $ov=$form->{ov};
        if($form->{id} && $ov->{num_sv1} && $ov->{num_sv2}){
          #return qq{
          #  <a href="/backend/DU/load/$form->{id}/ДУ_$form->{ov}->{num_sv1}-$form->{ov}->{num_sv2}-$form->{ov}->{num_sv3}.doc">Скачать протокол ДУ</a>
          #}
          my $filename="$ov->{dat_pov}.$ov->{num_sv2}.$ov->{num_sv1}";
          return qq{
            <a href="/backend/protocol/pdf/$form->{id}/$filename.pdf">Протокол поверки, pdf</a> |
            <a href="/backend/protocol/doc/$form->{id}/$filename.doc">Протокол поверки, doc</a>
          }
        }
        else{
          return ''
        }

      }
    },
    {
      description=>'Мастер',
      name=>'master_id',
      type=>'select_from_table',
      tablename=>'m',
      table=>'master',
      header_field=>'header',
      value_field=>'id',
      regexp=>'^\d+$',
      frontend=>{ajax=>{name=>'master_id'}}
    },
    {
      name => 'dat_pov', 
      description => 'Дата поверки',
      type => 'date',
      filter_on=>1,
      before_code=>sub{
        my $e=shift;
        if($form->{script} eq 'admin_table'){
          $form->{on_filters}->[0]->{value}=[cur_date(-1),cur_date(-1)];
        }
        
      },
      #not_order=>1,
      frontend=>{ajax=>{name=>'calc_dat_pov_next'}},
      tab=>'c1'
    },

    {
       name => 'num_sv2',
       description => 'Табельный номер эталона',
       type => 'select_from_table',
       table=>'main_master',
       header_field=>'tnumber',
       value_field=>'tnumber',
       regex=>'^.+$',
       tablename=>'mm',
       tab=>'c2',
       frontend=>{ajax=>{name=>'num_sv'}},
       #filter_on=>1
    },
    {
      name => 'num_sv1',
      description => 'Порядковый номер',
      type => 'text',
      regexp_rules=>[
        '/^[1-9]\d*$/','целое число'
      ],
      tab=>'c2',
      #filter_on=>1,
      frontend=>{ajax=>{name=>'check_num_sv1'}},
    },
    # {
    #   name => 'num_sv2',
    #   description => 'Табельный номер журнала',
    #   type => 'text',
    #   tab=>'c2',
    #   regexp_rules=>[
    #     '/^\d+$/','3 цифры'
    #   ],
    #   frontend=>{ajax=>{name=>'num_sv'}},
    #   filter_on=>1
    # },

    # {
    #   name => 'num_sv3',
    #   description => 'Год поверки',
    #   type => 'select_values',
    #   before_code=>sub{
    #     my $f=shift;
    #     my $cur_year=cur_year()-2000;
        
    #     if($form->{action} eq 'new'){
    #       $f->{value}=sprintf("%02d",$cur_year);
    #     }
    #     foreach my $y (1..$cur_year){

    #       my $v=sprintf("%02d",$y);

    #       push @{$f->{values}},{v=>$v,d=>$v};
    #     }
    #   },
    #   values=>[],
    #   tab=>'c2',
    #   regexp_rules=>[
    #     '/^\d{2}$/','2 цифры'
    #   ],
    #   filter_on=>1
    # },
    {
      description=>'№ свидетельства/извещения/протокола', # а карте
      name=>'num_label',
      type=>'text',
      #read_only=>1,
      not_process=>1,
      #filter_on=>1,
      before_code=>sub{
        my $e=shift;
        if($form->{script} eq 'find_objects'){
          $e->{db_name}='func::concat(wt.dat_pov,"/",wt.num_sv2,"/",wt.num_sv1)';
          $e->{not_process}=0
        }
      },
      #db_name=>'func::concat(wt.dat_pov,"/",wt.num_sv2,"/",wt.num_sv1)',
      filter_code=>sub{
        my $s=$_[0]->{str};
        if($s->{wt__dat_pov} && $s->{wt__num_sv2} && $s->{wt__num_sv1}){
          return qq{$s->{wt__dat_pov}/$s->{wt__num_sv2}/$s->{wt__num_sv1}}
        }
        return '-'
      }

      #tab=>'c2',
    },
    {
      description=>'Поверитель',
      type=>'select_from_table',
      table=>'main_master',
      tablename=>'mm',
      name=>'main_master_id',
      header_field=>'header',
      value_field=>'id',
      tab=>'c2',
      frontend=>{ajax=>{name=>'calc_num_sv1'}}
    },
    {
      description=>'Наим. в моей базе / модификация',
      regexp=>'\d+',
      type=>'filter_extend_select_from_table',
      name=>'f_grsi_mod',
      tree_use=>1,
      #filter_on=>1,
      not_process=>1,
      before_code=>sub{ # собираем select из двух таблиц, обработка фильтра в events.before_code
        my $e=shift;
        $e->{list}=[];
        my $list=$form->{db}->query(
          query=>q{
            SELECT * from
            (
                (
                select
                    concat('r',id) id, 0 parent,  header
                    from
                    reestr_si
                ORDER BY header
                )
                UNION
                (
                    select 
                        concat('r',r1.id,'-',r2.id) as id, 1 as parent, concat(r1.header,' / ',r2.header) header
                    from
                        reestr_si r1
                        JOIN reestr_si_modification r2 ON r1.id=r2.reestr_si_id
                    
                )
            ) x order by header, id desc,parent
          }
        );
        foreach my $l (@{$list}){
          if($l->{parent}){
            $l->{header}="..$l->{header}"
          }
          push @{$e->{list}},{v=>$l->{id},d=>$l->{header}};
        }
      },
      filter_code=>sub{
        my $s=$_[0]->{str};
        #pre($s);
        return $s->{rs__header}.' / '.$s->{modif__header};
      }


    },
    # Эталон
    {
      description=>'Номер ГРСИ',
      type=>'select_from_table',
      table=>'reestr_si',
      before_code=>sub{
        my $e=shift;
        
        if($form->{script} eq 'edit_form' || $form->{script} eq 'admin_table'){
          $e->{header_field}='concat(header," (",num_gos,")")'
        }
      },
      header_field=>'num_gos',
      tablename=>'rs',
      value_field=>'id',
      name=>'grsi_num', # [%grsi_num%]
      tab=>'c1',
      frontend=>{ajax=>{name=>'calc_dat_pov_next'}},
      not_filter=>1
    },
    {
      description=>'Модификация',
      type=>'select_values',
      #regexp=>'^\d+$',
      name=>'reestr_si_modification_id',
      not_filter=>1

    },
    # Наименование счётчика
    # тип счётчика воды
    # методика поверки




    {
      name => 'type_wather',
      description => 'ХВС/ГВС',
      type => 'select_values',
      values=>[
        {v=>'hv',d=>'ХВС'},
        {v=>'gv',d=>'ГВС'},
      ],
      regexp=>'^(hv|gv)$',
      tab=>'c1',
      frontend=>{ajax=>{name=>'calc_dat_pov_next'}},
      #filter_on=>1,
      filter_code=>sub{
        my $s=$_[0]->{str};
        if($s->{wt__type_wather} eq 'hv'){
          return 'ХВС'
        }
        if($s->{wt__type_wather} eq 'gv'){
          return 'ГВС'
        }
        return '-'
      }
    },
    {
      name => 'dn',
      description => 'Диаметр (Ду)',
      type => 'select_values',
      values=>[
        {v=>'15',d=>'Ду 15'},
        {v=>'20',d=>'Ду 20'},
      ],
      tab=>'c1',
      #filter_on=>1
    },
    {
      name => 'zav_num', # 
      description => 'Заводской номер',
      type => 'text',
      regexp_rules=>[
        '/^.+$/','укажите заводской номер'
      ],
      tab=>'c1',
      #filter_on=>1
    },
    {
      description=>'Год изготовления',
      name=>'born_year',
      type=>'text',
      regexp_rules=>[
        '/^\d{4}$/','год указан не корректно'
      ],
      tab=>'c1',
      values=>[],
      #filter_on=>1
    },
    {
      name => 'is_ok',
      description => 'Годен/не годен',
      type => 'select_values',
      before_code=>sub{
        my $e=shift;
        if($form->{action} eq 'new'){
          $e->{value}=1
        }
      },
      values=>[
        {v=>0,d=>'не годен'},
        {v=>1,d=>'годен'},
      ],
      tab=>'c2',
      frontend=>{ajax=>{name=>'calc_dat_pov_next'}},
      #filter_on=>1
    },
    {
      description=>'Действительно до', # Дата очередной поверки
      name=>'dat_pov_next',
      type=>'date',
      tab=>'c1',
      #filter_on=>1
    },
    # {
    #     description=>'Адрес',
    #     type=>'text',

    #     name=>'address',
    #     subtype=>'dadata_address',
    #     dadata=>{
    #         API_KEY=>'0504bf475461ecb2b0223936a54ea814d2fc59d2',
    #         SECRET_KEY=>'60df5c61174703321131e32104288e324733a2f5',

    #     },
    #     prefix_list_header=>'Укажите регион',
    #     prefix_list=>['Москва','Московская обл','Калужская обл'],
    #     change_in_search=>1,
    #     regexp_rules=>[
    #       '/^.+$/','заполните адрес'
    #     ],
    #     tab=>'c1',
    # },
    {
      name => 'address',
      description => 'Адрес',
      type => 'text',
      subtype=>'kladr',
      regexp_rules=>[
        '/^.+$/','заполните адрес'
      ],
      tab=>'c1',
      prefix_list_header=>'Укажите регион',
      prefix_list=>['Москва','Московская обл','Калужская обл'],
      kladr=>{
        after_search=>sub{
          my $data=shift; my $i=0;
          my $list=[];
          foreach my $d (@{$data}){
            
            my @res=();
            foreach my $d2 (@{$d->{parents}}){
              
              # пропускаем регион "Москва", если у нас город "Москва"
              if($d2->{name} eq 'Москва' && $d2->{contentType} ne 'city'){
                next
              }
              if($d2->{zip} eq '123182' && $d2->{contentType} eq 'city'){
                pop @res;
              }

              push @res,"$d2->{typeShort} $d2->{name}"
            }

            push @res,"$d->{typeShort} $d->{name}";
            my $h=join(', ',@res);
            # Encode::_utf8_on($h);
            # {
            #   use utf8;
            #   $h=~s/^г Москва,\s+(г Москва)/$1/g;
            # }
            
            #print "$h\n";
            push @{$list},{header=>$h};
          }
          return $list;
        },
      },

      
      #filter_on=>1
    },
    {
      description=>'Заказчик',
      type=>'text',
      name=>'owner'
    }
	]
};



