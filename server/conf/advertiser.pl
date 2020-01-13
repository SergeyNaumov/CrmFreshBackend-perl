$form={
    title=>'Рекламодатели',
    header_field=>'header',
    work_table=>'advertiser',
    work_table_id=>'id',
    tree_use=>0,
    sort=>1,
    events=>{
      permissions=>sub{
        if($form->{id}){
          $form->{title}='Рекламодатель';
          #$form->{ov}=$form->{db}->query(query=>'SELECT * from manager_menu where id=?',values=>[$form->{id}],onerow=>1);
        }
      }
    },
    default_find_filter=>'header',

    fields=>[
      {
          description=>'Наименование',
          type=>'text',
          name=>'header',
          filter_on=>1
      },
      
    ]
};