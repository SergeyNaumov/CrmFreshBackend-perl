$form={
  title => 'Статьи',
  work_table => 'article',
  work_table_id => 'id',
  make_delete => '1',
  header_field=>'header',
  default_find_filter => 'header',
  #sort_field=>'header',
  #tree_use => '1',
  explain=>0,
  GROUP_BY=>'wt.id',
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
    },
    after_save=>sub{
      if($form->{new_values}->{top}){
        $form->{db}->query(query=>'UPDATE article set top=0 where id<>?',values=>[$form->{id}])
      }
    }
  },
  QUERY_SEARCH_TABLES=>[
    {t=>'article',a=>'wt'},
    {t=>'manager',a=>'m',l=>'wt.manager_id=m.id',left_join=>1,for_fields=>['manager_id']},
    {t=>'article_rubric',a=>'ar',l=>'ar.id=wt.rubric_id',lj=>1},
    {t=>'article_tag',a=>'ar_t',l=>'wt.id=ar_t.article_id',lj=>1,for_fields=>['tags'],not_add_in_select_fields=>1},
    {t=>'tag',a=>'t',l=>'ar_t.tag_id=t.id',lj=>1,for_fields=>['tags'],not_add_in_select_fields=>1},
  ],
  fields =>
  [
    {
      name => 'header', # наименование поля
      description => 'Название',
      type => 'text',
      full_str=>1,
      filter_on=>1,
      regexp_rules=>[
        q{/^.+$/},'Заполните заголовок',
        #q{/^.{1,3}$/},'Заголовок слишком короткий',
        q{/^.{3,255}$/},'Заголовок слишком длинный',
      ]
    },
    {
      description=>'Автор',
      table=>'manager',
      type=>'select_from_table',
      name=>'manager_id',
      table=>'manager',
      header_field=>'name',
      value_field=>'id',
      tablename=>'m',
      make_change_in_search=>1
    },
    {
      description=>'Рубрика статьи',
      type=>'select_from_table',
      table=>'article_rubric',
      name=>'rubric_id',
      tablename=>'ar',
      #header_field=>'header',
      #value_field\
    },
    {
      description=>'Отображать на сайте',
      type=>'switch',
      name=>'enabled'
    },
    {
      description=>'Главная новость',
      type=>'switch',
      name=>'top'
    },
    {
      name=>'anons',
      description=>'Анонс',
      type=>'textarea',
      full_str=>1,
      style=>'height: 100px'
    },
    {
      description=>'Фото',
      type=>'file',
      name=>'photo',
      filedir=>'./files/article',
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
        {
          description=>'Фото для страницы статьи',
          file=>'<%filename_without_ext%>_mini4.<%ext%>',
          size=>'1165x672',
          quality=>'70'
        },
      ]
    },
    {
      name => 'body',
      description => 'Текст',
      full_str=>1,
      type => 'wysiwyg',
    },
    {
      description=>'Тэги',
      type=>'multiconnect',
      name=>'tags',
      tablename=>'t',
      relation_table=>'tag',
      relation_save_table=>'article_tag',
      relation_table_header=>'header',
      relation_table_id=>'id',
      relation_save_table_id_worktable=>'article_id',
      relation_save_table_id_relation=>'tag_id',
      make_add=>1,
      view_only_selected=>1,
      cols=>3,
      not_order=>1,
      tab=>'tags'
    },
    {
      description=>'Дата создания',
      name=>'registered',
      type=>'datetime',
      filter_on=>1,
      default_off=>1,
      full_str=>1,
      before_code=>sub{
        my $e=shift;
        

        if($form->{action} eq 'new'){
          #$e->{read_only}=0
          my ($day,$mon,$year,$hour,$min,$sec)=( localtime(time) )[3,4,5,2,1,0];
          $e->{value}=sprintf("%04d-%02d-%02d %02d:%02d:%02d",$year+1900,$mon+1,$day,$hour,$min,$sec);
        }
      }
    }
  ]
};
