$form={
    title=>'Статусы в карточке клиента',
    header_field=>'header',
    tree_use=>0,
    sort=>1,
    #read_only=>1,
    events=>{
      permissions=>sub{
        if($form->{id}){
          $form->{title}='Редактирование пункта меню'
        }
      }
    },
    fields=>[
      {
          description=>'Наименование пункта меню',
          type=>'text',
          name=>'header',
      },

    ]
};
