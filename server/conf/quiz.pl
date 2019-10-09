$form={
    title=>'Опросник',
    work_table=>'quiz',
    work_table_id=>'id',
    header_field=>'header',
    default_find_filter=>'<%header%>',
    #tree_use=>1,
    sort=>1,
    events=>{
      permissions=>sub{
        if($form->{id}){
          $form->{title}='Редактирование вопроса'
        }
      }
    },
    default_find_filter=>'header',

    fields=>[
      {
          description=>'Наименование',
          type=>'text',
          name=>'header',
          tab=>'main'
      },
      {
        description=>'Вопросы',
        name=>'questions',
        type=>'1_to_m',
        table=>'quiz_question',
        table_id=>'id',
        foreign_key=>'quiz_id',
        sort=>1,
        fields=>[
          {
            description=>'Вопрос',
            type=>'textarea',
            name=>'header'
          },
          {
            description=>'Варианты ответа на вопрос',
            type=>'select_values',
            name=>'type',
            values=>[
              {v=>1,d=>'письменный ответ (в текстовом поле)'},
              {v=>2,d=>'один из перечисленных вариантов'},
              {v=>3,d=>'несколько перечисленных вариантов'},

            ]
          },
          {
            description=>'Выводить текстовое поле',
            name=>'out_text_field',
            default_label_empty=>'Не выводить',
            type=>'select_values',
            values=>[
              {v=>1,d=>'выводить поле text'},
              {v=>2,d=>'выводить поле textarea'},
            ]
          }
        ]
      }

    ]
};