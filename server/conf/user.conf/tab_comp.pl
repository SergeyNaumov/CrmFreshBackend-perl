# {
#   name=>'button_tab_comp',
#   type=>'save_button',
#   tab=>'comp'
# },
{
  description=>'Название организации',
  regexp=>'^.+$',
  name=>'firm',
  type=>'text',
  tab=>'comp',
  make_change_in_search=>1,
  before_code=>sub{
    my $e=shift;
    if($form->{script} eq 'admin_table'){
      $e->{filter_on}=1;
      #$e->{value}='Завод'
    }
    #push @{$form->{log}},$form->{script};
    #$form->{self}->pre($form->{script});
    # if($form->{script} eq 'admin_table'){
    #   
    #   $e->{value}='Завод'
    # }

  },
  filter_code=>sub{
    my $s=$_[0]->{str};
    $s->{wt__firm}='----' unless($s->{wt__firm});
    $s->{wt__firm}=~s{([a-zA-Z]+)}{<span style="color: red;">$1</span>}gs;
    my $ID;
    if(param('view_user_id')){
      $ID="ID: $s->{wt__id} | ";
    }
    return qq{<a href="/edit_form/user/$s->{wt__id}" target="_blank">$s->{wt__firm}</a>};
  }
},
{
  description=>'Отрасль',
  name=>'otr_id',
  type=>'select_from_table',
  table=>'otr',
  header_field=>'header',
  value_field=>'id',
  tab=>'comp',
  #filter_code=>sub{
    #my $e=shift; 
    #pre("test");
   # use Data::Dumper;
   #$form->{self}->pre('zzz');
    #$form->{self}->pre(555);
  #}
},
{
  description=>'Регион',
  name=>'region_id',
  type=>'select_from_table',
  table=>'region',
  header_field=>'header',
  value_field=>'id',
  tab=>'comp',
  tablename=>'region',
  where=>'country_id=1',
  code=>sub{
    my $e=shift;
    my $field='';
    if(exists($form->{old_values}->{region_timeshift})){
      $field.=qq{  ($form->{old_values}->{region_timeshift})}
    }
    return $field;
  },
  filter_code=>sub{
    my $s=$_[0]->{str};
    if($s->{region__id}){
      return qq{$s->{region__header} ($s->{region__timeshift})}
    }
    else{
      return '-'
    }
    
  }
},
{
  description=>'Сайт',
  name=>'web',
  type=>'text',
  filter_code=>sub{
    my $e=shift;
    my $for_out='';
    
    while($e->{str}->{wt__web}=~m{(\S+)}gs){
    
      my $w=$1;
      if($w=~m{^https?:\/\/}i){
        $w=qq{<a href="$w" target="_blank">$w</a>}
      }
      if($for_out){
        $for_out.=' ';
      }
      $for_out.=$w;
    }
    return $for_out;
  },
  tab=>'comp',
},
{
  description=>'Тип компании',
  type=>'select_values',
  name=>'company_type',
  values=>[
    {v=>1,d=>'Юр. Лицо'},
    {v=>2,d=>'ИП'},
    
  ],
  tab=>'comp'
},
{
  description=>'Тип клиента',
  type=>'select_values',
  name=>'company_role',
  regexp=>'^[12]$',
  before_code=>sub{ # из-за плясок с синхронизацией поле не должно быть пустым и после создания не меняется
    my $e=shift;
    #print Dumper([e=>$e,manager=>$form->{manager}]);
    if($form->{action}=~m{^(new|insert)$} || $form->{manager}->{login}=~m{^(admin|skrash)$}){
      $e->{read_only}=0;
      
      unless($form->{manager}->{login}=~m{^(admin|skrash)$}){
         $e->{values}=[{v=>1,d=>'Поставщик'}]
       
      }
    }
  },
  read_only=>1,
  values=>[
    {v=>1,d=>'Поставщик'}, # supplier_2_<ID>
    {v=>2,d=>'Заказчик'}, #  contractor_2_<ID>
    
  ],
  tab=>'comp'
},
{
  description=>'Описание',
  type=>'textarea',
  name=>'more_info',
  tab=>'comp'
},
{
  description=>'Документы компании',
  type=>'1_to_m',
  name=>'user_doc',
  table=>'user_doc',
  table_id=>'id',
  foreign_key=>'user_id',
  fields=>[
    {description=>'Файл',name=>'attach',type=>'file',filedir=>'./files/user_doc'},
    {description=>'Комментарий',name=>'header',type=>'text'},
  ],
  tab=>'comp'
},
{ 
  name=>'btn1',
  tab=>'comp',
  type=>'save_button',
},
[%INCLUDE './conf/user.conf/field_contacts.pl'%]

