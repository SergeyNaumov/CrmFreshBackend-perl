$form={
  title => 'Текстовые страницы',
  work_table => 'text_page',
  work_table_id => 'id',
  make_delete => '1',
  header_field=>'header',
  default_find_filter => 'header',
  #sort_field=>'header',
  #tree_use => '1',
  #explain=>0,
  events=>{
    permissions=>sub{
      if($form->{manager}->{login} eq 'admin' || $form->{manager}->{permissions}->{content}){
        $form->{not_create}=0;
      }
      else{
        #print_header();
        #print "Доступ запрещён!" ; exit;
        push @{$form->{errors}},'Доступ запрещён';
      }
    }
  },
  QUERY_SEARCH_TABLES=>[
    {t=>'text_page',a=>'wt'},
  ],
  fields =>
  [
    {
      description=>'url',
      add_description=>'url Обязателен',
      name=>'url',
      type=>'text',
      regexp_rules=>[

        '/.+/','Обязателен для заполнения',
        '/^\/.+$/','Должен начинаться с /',
        '/^[\/a-z\-A-Z0-9]+$/','недопустимые символы в url',
      ],
      replace_rules=>[
          '/^([^\/])/'=>'/$1',
      ],
      ajax_rules=>[
        {
          url=>'/edit_form/text_page',
          action=>'check_unique_url'
        }
      ]
    },
    {
      name => 'header', # наименование поля
      description => 'Название',
      frontend=>{
        fields_dependence=>q{[%INCLUDE './conf/text_page.conf/dependence_header.js'%]}
      },
      type => 'text',
      full_str=>1,
      filter_on=>1,
      regexp_rules=>[
        q{/^.+$/},'Заполните заголовок',
        q{/^.{3,255}$/},'Заголовок слишком длинный',
      ]
    },
    {
      description=>'Фото',
      type=>'file',
      name=>'photo',
      filedir=>'./files/text_page',
      # .accept=>'doc,.docx,.xml,application/msword,application/vnd.openxm
      #accept=>'image/png, image/jpeg',
      #accept=>'image/*',
      crops=>1,
      resize=>[
        {
          description=>'Горизонтальное фото',
          file=>'<%filename_without_ext%>_mini2.<%ext%>',
          size=>'502x245',
          quality=>'70'
        },
        {
          description=>'Вертикальное фото',
          file=>'<%filename_without_ext%>_mini1.<%ext%>',
          size=>'244x504',
          quality=>'70'
        },
        {
          description=>'Квадратное фото',
          file=>'<%filename_without_ext%>_mini3.<%ext%>',
          size=>'245x245',
          quality=>'70'
        },
      ]
    },
    {
      name => 'body',
      description => 'Текст',
      full_str=>1,
      type => 'wysiwyg',
    }
  ]
};
