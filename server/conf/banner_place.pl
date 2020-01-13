$form={
    title=>'Баннерные площадки',
    header_field=>'header',
    work_table=>'banner_place',
    work_table_id=>'id',
    make_delete=>0,
    tree_use=>0,
    sort=>0,
    events=>{
      permissions=>sub{
        if($form->{id}){
          
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