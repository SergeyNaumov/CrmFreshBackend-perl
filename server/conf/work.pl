
$form={
	title => 'Выполненные работы',
	work_table => 'work',
	work_table_id => 'id',
	make_delete => '0',
  not_create=>1,
  
	tree_use => '0',
  #explain=>1,

	events=>{
		permissions=>[
      sub{
        if($form->{manager}->{login} eq 'admin' || $form->{manager}->{permissions}->{operator}){
            $form->{make_delete}=1;
            $form->{read_only}=0;
            $form->{not_create}=0,
        }
      }
      
    ],
  },
  AJAX=>{
    check_num_sv1=>sub{
      my $s=shift; my $v=shift;
      if($v->{num_sv1}!~m/^\d{5}$/){
        return [
          'num_sv1',{error=>'должно быть 5 цифр'}
        ]
      }
      elsif($v->{num_sv2}=~m/^\d{3}$/ && $v->{num_sv3}=~m/^\d{4}$/){
        
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
      }
      return [
        'num_sv1',{error=>''}
      ]
    },
    num_sv=>sub{ # вычисляем номер сивдетельства
      my $s=shift; my $v=shift;
      my $result=[];
      
      my $master=$form->{db}->query(
        query=>'SELECT id from master where tnumber=?',
        values=>[$v->{num_sv2}], onerow=>1
      );
      if($master){
        #if(!$v->{num_sv1}){
          if($v->{num_sv2} && $v->{num_sv3}){
            my $num_sv1=$form->{db}->query(
              query=>'SELECT max(num_sv1) from work WHERE num_sv2=? and num_sv3=?',
              values=>[$v->{num_sv2},$v->{num_sv3}],
              onevalue=>1,
            );
            $num_sv1=sprintf("%05d",$num_sv1+1);
            



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
  cols=>[
    [
      {name=>'c1'}
    ],
    [
      {name=>'c2',description=>'ГРСИ и мастер'}
    ]
  ],
  QUERY_SEARCH_TABLES=>
  [
    {table=>'work',alias=>'wt'},
    
  ],
  search_on_load=>1,
  fields =>
  [
    {
      name => 'address',
      description => 'Адрес',
      type => 'text',
      subtype=>'kladr',
      regexp_rules=>[
        '/^.+$/','заполните адрес'
      ],
      tab=>'c1',
      filter_on=>1
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
      description=>'Номер ГРСИ',
      type=>'select_from_table',
      table=>'reestr_si',
      header_field=>'id',
      value_field=>'id',
      name=>'grsi_num',
      tab=>'c1',
      frontend=>{ajax=>{name=>'calc_dat_pov_next'}},
    },
    {
      description=>'Номер свидетельства / извещения / протокола', # а карте
      name=>'num_label',
      type=>'text',
      read_only=>1,
      not_process=>1,
      tab=>'c2',
    },
    {
      name => 'num_sv1',
      description => 'Свидетельство - порядковый номер',
      type => 'text',
      regexp_rules=>[
        '/^\d{5}$/','5 цифр'
      ],
      tab=>'c2',
      filter_on=>1,
      frontend=>{ajax=>{name=>'check_num_sv1'}},
    },
    {
      name => 'num_sv2',
      description => 'Свидетельство',
      type => 'text',
      tab=>'c2',
      regexp_rules=>[
        '/^\d{3}$/','3 цифры'
      ],
      frontend=>{ajax=>{name=>'num_sv'}},
      filter_on=>1
    },
    {
      name => 'num_sv3',
      description => 'ГРСИ - год',
      type => 'text',
      before_code=>sub{
        my $f=shift;
        if($form->{action} eq 'new'){
          $f->{value}=cur_year()
        }
      },
      tab=>'c2',
      regexp_rules=>[
        '/^\d{4}$/','4 цифры'
      ],
      filter_on=>1
    },
    {
      description=>'Мастер',
      type=>'select_from_table',
      table=>'master',
      name=>'master_id',
      header_field=>'header',
      value_field=>'id',
      tab=>'c2'
    },
    {
      name => 'type_wather',
      description => 'Водоснабжение',
      type => 'select_values',
      values=>[
        {v=>'hv',d=>'Х/В'},
        {v=>'gv',d=>'Г/В'},
      ],
      tab=>'c1',
      frontend=>{ajax=>{name=>'calc_dat_pov_next'}},
      filter_on=>1
    },
    {
      description=>'Следующая дата поверки',
      name=>'dat_pov_next',
      type=>'date',
      tab=>'c1',
      filter_on=>1
    },
    {
      name => 'dn',
      description => 'Диаметр (DN)',
      type => 'select_values',
      values=>[
        {v=>'15',d=>'ДУ15'},
        {v=>'20',d=>'ДУ20'},
      ],
      tab=>'c1',
      filter_on=>1
    },
    {
      name => 'zav_num',
      description => 'Заводской номер',
      type => 'text',
      regexp_rules=>[
        '/^.+$/','укажите заводской номер'
      ],
      tab=>'c1',
      filter_on=>1
    },
    {
      description=>'Год выпуска',
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
      description => 'Годен',
      type => 'switch',
      tab=>'c2',
      filter_on=>1
    },

	]
};



