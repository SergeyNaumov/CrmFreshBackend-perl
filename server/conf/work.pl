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

	events=>{
		permissions=>[


      sub{
        use Plugin::Search::XLS;
        use Plugin::Search::CSV;
        
        Plugin::Search::XLS::go($form);
        Plugin::Search::CSV::go($form);


        if($form->{manager}->{login} eq 'admin' || $form->{manager}->{permissions}->{operator}){
            $form->{make_delete}=1;
            $form->{read_only}=0;
            $form->{not_create}=0,
        }
        if($form->{id}){
          $form->{ov}=$form->{db}->query(
            query=>'select * from work where id=?',
            values=>[$form->{id}],
            onerow=>1
          )
        }
      }
      
    ],
  },
  AJAX=>{
    check_num_sv1=>sub{
      my $s=shift; my $v=shift;
      if($v->{num_sv1}!~m/^\d+$/){
        return [
          'num_sv1',{error=>'номер не указан или указан не корректно'}
        ]
      }
      elsif($v->{num_sv2}=~m/^\d{3}$/ && $v->{num_sv3}=~m/^\d{2}$/){
        
        my @where="(num_sv1=? and num_sv2=? and num_sv3=?)";
        if($form->{id}){
          push @where,"(id <> $form->{id})"
        }
        
        my $exists_num=$s->{db}->query(
          query=>"select * from work WHERE ".join(' AND ',@where),
          values=>[$v->{num_sv1},$v->{num_sv2},$v->{num_sv3}],
          onerow=>1
        );
        if($exists_num){
          return [
            'num_sv1',{error=>qq{такой номер уже есть: <a href="/edit_form/work/$exists_num->{id}" target="_blank">здесь</a>}}
          ]
        }
        return [
          'num_label',{value=>"$v->{num_sv1}/$v->{num_sv2}/$v->{num_sv3}"},
          'num_sv1',{error=>''}
        ]
      }
      return [
        'num_sv1',{error=>''},

      ]
    },
    num_sv=>sub{ # вычисляем номер свидетельства
      my $s=shift; my $v=shift;
      my $result=[];
      
      my $master=$form->{db}->query(
        query=>'SELECT id from master where tnumber=?',
        values=>[$v->{num_sv2}], onerow=>1
      );
      if($master){
        #if(!$v->{num_sv1}){
          if($v->{num_sv2} && $v->{num_sv3}){
            my $where='num_sv2=? and num_sv3=?';
            if($form->{id}){
              $where.=" and id<>$form->{id}"
            }
            my $num_sv1=$form->{db}->query(
              query=>'SELECT max(num_sv1) from work WHERE '.$where,
              values=>[$v->{num_sv2},$v->{num_sv3}],
              onevalue=>1,
            );
            $num_sv1++;

            if($num_sv1 ne $v->{num_sv1}){
              $v->{num_sv1}=$num_sv1;
              my $warning='';
              push @{$result},('num_sv1',{value=>$num_sv1,error=>'',warning=>$warning});
            }
            
          }
        #}
        push @{$result},(
          'master_id',{value=>$master->{id}},
          'num_label',{
            value=>"$v->{num_sv1}/$v->{num_sv2}/$v->{num_sv3}",
            error=>'',
          },
          'num_sv2',{error=>''}
        );


      }
      else{
        $result=[
          'num_sv2',
          {
            error=>'табельный номер не найден'
          },
          'num_label',{value=>'', error=>'не получится вычислить, поскольку не найден табельный номер'}
        ]

      }

      return $result

      # return [
      #   login=>{
      #     error=>$exists?'такой логин уже существует':''
      #   }
      # ]
    },
    calc_dat_pov_next=>sub{
      my $s=shift; my $v=shift;
      if($v->{grsi_num} && $v->{grsi_num}=~m/^\d+$/ && $v->{dat_pov}=~m/[1-9]/ && $v->{type_wather}){
        my $reestr=$s->{db}->query(
          query=>'select * from reestr_si where id=?',
          values=>[$v->{grsi_num}],
          onerow=>1
        );
        if($reestr){
          my $delta=($v->{type_wather} eq 'gv')?$reestr->{pov_g}:$reestr->{pov_h};
          if($v->{dat_pov}=~m/^(\d{4})-(\d{2})-(\d{2})$/){
            my ($y,$m,$d)=($1,$2,$3);
            $y+=$delta;
            return [
              'dat_pov_next',{value=>"$y-$m-$d"},
              #'dat_pov',{error=>''},
              #'grsi_num',{error=>''},
            ]
          }
          else{
            return ['dat_pov',{error=>"какая-то странная у Вас дата"}]
          }
        }
        else{
          return ['grsi_num',{error=>"Номер $v->{grsi_num} не найден в реестре СИ"}]
        }

        
      }
      return []
    }
  },
  # cols=>[
  #   [
  #     {name=>'c1'}
  #   ],
  #   [
  #     {name=>'c2',description=>'ГРСИ и мастер'}
  #   ]
  # ],
  QUERY_SEARCH_TABLES=>
  [
    {table=>'work',alias=>'wt'},
    
  ],
  search_on_load=>1,
  fields =>
  [
    {
      description=>'Ссылки',
      type=>'code',
      name=>'links',
      code=>sub{
        if($form->{id}){
          return qq{
            <a href="http://dev-crm.test/backend/DU/load/$form->{id}/ДУ.doc">Скачать протокол ДУ</a>
          }
        }
        else{
          return ''
        }

      }
    },
    {
      name => 'dat_pov', 
      description => 'Дата поверки',
      type => 'date',
      filter_on=>1,
      frontend=>{ajax=>{name=>'calc_dat_pov_next'}},
      tab=>'c1'
    },

    {
      name => 'num_sv1',
      description => 'Порядковый номер по журналу',
      type => 'text',
      regexp_rules=>[
        '/^[1-9]\d*$/','целое число'
      ],
      tab=>'c2',
      filter_on=>1,
      frontend=>{ajax=>{name=>'check_num_sv1'}},
    },
    {
      name => 'num_sv2',
      description => 'Табельный номер журнала',
      type => 'text',
      tab=>'c2',
      regexp_rules=>[
        '/^\d+$/','3 цифры'
      ],
      frontend=>{ajax=>{name=>'num_sv'}},
      filter_on=>1
    },
    {
      name => 'num_sv3',
      description => 'Год поверки',
      type => 'select_values',
      before_code=>sub{
        my $f=shift;
        my $cur_year=cur_year()-2000;
        
        if($form->{action} eq 'new'){
          $f->{value}=sprintf("%02d",$cur_year);
        }
        foreach my $y (1..$cur_year){

          my $v=sprintf("%02d",$y);

          push @{$f->{values}},{v=>$v,d=>$v};
        }
      },
      values=>[],
      tab=>'c2',
      regexp_rules=>[
        '/^\d{2}$/','2 цифры'
      ],
      filter_on=>1
    },
    {
      description=>'№ свидетельства/извещения/протокола', # а карте
      name=>'num_label',
      type=>'text',
      read_only=>1,
      not_process=>1,
      tab=>'c2',
    },
    {
      description=>'Поверитель',
      type=>'select_from_table',
      table=>'master',
      name=>'master_id',
      header_field=>'header',
      value_field=>'id',
      tab=>'c2'
    },
    # Эталон
    {
      description=>'Номер ГРСИ',
      type=>'select_from_table',
      table=>'reestr_si',
      header_field=>'id',
      value_field=>'id',
      name=>'grsi_num', # [%grsi_num%]
      tab=>'c1',
      frontend=>{ajax=>{name=>'calc_dat_pov_next'}},
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
      tab=>'c1',
      frontend=>{ajax=>{name=>'calc_dat_pov_next'}},
      filter_on=>1
    },
    {
      name => 'dn',
      description => 'Диаметр (DN)',
      type => 'select_values',
      values=>[
        {v=>'15',d=>'DN15'},
        {v=>'20',d=>'DN20'},
      ],
      tab=>'c1',
      filter_on=>1
    },
    {
      name => 'zav_num', # 
      description => 'Заводской номер',
      type => 'text',
      regexp_rules=>[
        '/^.+$/','укажите заводской номер'
      ],
      tab=>'c1',
      filter_on=>1
    },
    {
      description=>'Год изготовления',
      name=>'born_year',
      type=>'select_values',
      before_code=>sub{
        my $e=shift;
        my $cur_year=cur_year();
        for my $y (2000..$cur_year){
          push @{$e->{values}},{v=>$y,d=>$y}
        }
        #pre($e);
      },
      tab=>'c1',
      values=>[],
      filter_on=>1
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
      filter_on=>1
    },
    {
      description=>'Дата очередной поверки',
      name=>'dat_pov_next',
      type=>'date',
      tab=>'c1',
      filter_on=>1
    },
    {
      name => 'address',
      description => 'Адрес',
      type => 'text',
      subtype=>'kladr',
      regexp_rules=>[
        '/^.+$/','заполните адрес'
      ],
      tab=>'c1',
      kladr=>{
        after_search=>sub{
          my $data=shift; my $i=0;
          my $list=[];
          foreach my $d (@{$data}){
            
            my @res=();
            foreach my $d2 (@{$d->{parents}}){
              
              # пропускаем регион "Москва", если у нас город "Москва"
              if($d2->{zip} eq '123182' && $d2->{contentType} eq 'city'){
                pop @res;
              }
              if($d2->{zip} eq '123182' && $d2->{contentType} eq 'cityOwner'){
                next;
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

      
      filter_on=>1
    },
    {
      description=>'Заказчик',
      type=>'text',
      name=>'owner'
    }
	]
};



