$form={
  title => 'Статьи',
  work_table => 'article',
  work_table_id => 'id',
  make_delete => '1',
  header_field=>'header',
  default_find_filter => 'header',
  #sort_field=>'header',
  #tree_use => '1',
  events=>{
    permissions=>sub{
      if($form->{manager}->{login} eq 'admin' || $form->{manager}->{permissions}->{content}){
        $form->{not_create}=0;
      }
      else{
        print_header();
        print "Доступ запрещён!" ; exit;
      }
    }
  },
  #explain=>1,
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
        q{/.{10}/},'Заголовок слишком короткий',
        q{/^.{10,255}$/},'Заголовок слишком длинный',
      ]
    },
    {
      description=>'Отображать на сайте',
      type=>'switch',
      name=>'enabled'
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
          file=>'<%filename_without_ext%>_mini1.<%ext%>',
          size=>'100x200',
          grayscale=>1,
          quality=>'80'
        },
        {
          
          file=>'<%filename_without_ext%>_mini2.<%ext%>',
          size=>'200x100',
          grayscale=>1,
          composite_file=>'./files/logo.png',
        },
        {
          
          file=>'<%filename_without_ext%>_mini3.<%ext%>',
          size=>'200x200'
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
      relation_table=>'tag',
      relation_save_table=>'test_tag',
      relation_table_header=>'header',
      relation_table_id=>'id',
      relation_save_table_id_worktable=>'test_id',
      relation_save_table_id_relation=>'tag_id',
      make_add=>1,
      view_only_selected=>1,
      cols=>3,
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
