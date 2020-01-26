$form={
    title=>'Пункты меню',
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
    cols=>[
      [{name=>'main',description=>'Основные Параметры'}],
      [{name=>'advanced',description=>'Дополнительные Параметры'}]
    ],
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
        before_code=>sub{
          my $e=shift;
          $e->{value}='vue' if(!$e->{value} && $form->{action}=~m/^(new|edit)$/); 
        },
        values=>[
          {v=>'',d=>'не выбрано'},
          {v=>'vue',d=>'VUE'},
          {v=>'src',d=>'internal_prog'},
        ],
        tab=>'main'
        #filter_code=>sub{
        #  use Data::Dumper;
          #return Dumper($_[0]->{str}->{wt__type})
        #}
      },
      {
        description=>'Значение',
        type=>'select_values',
        name=>'value',

        values=>[
          {v=>'admin-table',d=>'admin-table'},
          {v=>'admin-tree',d=>'admin-tree'},
          {v=>'const',d=>'const'},
          {v=>'parser-excel',d=>'parser-excel'},
        ],
        tab=>'main'
      },
      {
        description=>'Иконка',
        name=>'icon',
        type=>'font-awesome',
        tab=>'advanced'
      },
      {
        description=>'Параметры запуска',
        name=>'params',
        type=>'textarea',
        before_code=>sub{
          my $e=shift;
          unless($e->{value}){
            $e->{value}=qq{{"config":""}}
          }
        },
        add_description=>q{
          для типа vue например: {"config":"manager"}
        },
        tab=>'advanced'
      },
      {
        name => 'permissions',
        description => 'Права доступа',
        type => '1_to_m',
        table => 'manager_menu_permissions',
        table_id => 'id',
        foreign_key => 'menu_id',
        tab=>'advanced',
        fields =>
        [
          {
            description=>'Право доступа',
            name=>'permission_id',
            type=>'select_from_table',
            order=>'sort',
            tree_use=>1,
            table=>'permissions',
            value_field=>'id',
            header_field=>'header',
          },
          {
            description=>'Если включено, то',
            name=>'denied',
            type=>'select_values',
            values=>[
              {v=>0,d=>'давать доступ'},
              {v=>1,d=>'запрещать доступ'}
            ]
          },
        ]
      },
    ]
};
