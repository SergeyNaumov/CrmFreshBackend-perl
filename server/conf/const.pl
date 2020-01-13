$form={
    title=>'Константы',
    header_field=>'header',
    tree_use=>1,
    sort=>1,
    max_level=>2,
    events=>{
      permissions=>sub{
        if($form->{id}){
          $form->{title}='Редактирование пункта меню'
        }
      }
    },
    default_find_filter=>'header',

    fields=>[
      {
          description=>'Наименование пункта меню',
          type=>'text',
          name=>'header',
          tab=>'main'
      },
      {
        description=>'Тип элемента',
        type=>'select_values',
        name=>'type',
        permissions=>sub{
          my $e=shift;
          $e->{value}='vue' if($form->{action} eq 'new');
          #print "action: $form->{action}\n";
        },
        values=>[
          {v=>'',d=>'не выбрано'},
          {v=>'text',d=>'text'},
          {v=>'textarea',d=>'textarea'},
        ],
        
        tab=>'main'
      },

    ]
};