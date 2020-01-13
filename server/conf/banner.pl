$form={
    title=>'Баннеры',
    header_field=>'header',
    work_table=>'banner',
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
      {
        description=>'url',
        name=>'url',
        type=>'text'
      },
      {
        description=>'Размещение на площадках',
        type=>'1_to_m',
        name=>'bplace',
        table=>'banner_banner_place',
        foreign_key=>'banner_id',
        table_id=>'id',
        fields=>[
          {
            description=>'Площадка',
            type=>'select_from_table',
            table=>'banner_place',
            name=>'banner_place_id',
            order=>'sort'
          },
          {
            description=>'Фото',
            name=>'photo',
            type=>'file',
            filedir=>'./files/partner'
          },
          {
            description=>'Вкл',
            type=>'switch',
            name=>'enabled',
          }
        ]
      },
      # {
      #   description=>'Фото',
      #   type=>'file',
      #   name=>'photo'
      #   filedir=>'./files/partner'
      # }
      
    ]
};