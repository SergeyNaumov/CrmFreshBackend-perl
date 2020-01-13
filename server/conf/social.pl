
$form={
    title=>'Соцсети',
    header_field=>'header',
    work_table=>'social',
    work_table_id=>'id',
    tree_use=>0,
    sort=>1,
    events=>{
      permissions=>sub{
        if($form->{id}){
          #$form->{title}='Редактирование пункта меню';
          
          #$form->{ov}=$form->{db}->query(query=>'SELECT * from manager_menu where id=?',values=>[$form->{id}],onerow=>1);
        }
      }
    },
    default_find_filter=>'header',

    fields=>[
      {
          description=>'Наименование пункта меню',
          type=>'text',
          name=>'header',
      },
      {
        description=>'Логотип',
        add_description=>'25x25, белое',
        name=>'photo1',
        type=>'file',
        filedir=>'./files/social'
      },
      {
        description=>'Логотип',
        add_description=>'25x25, чёрное',
        name=>'photo2',
        type=>'file',
        filedir=>'./files/social'
      },
      {
          description=>'Url',
          type=>'text',
          name=>'url',
      },
    ]
};