
my $galery_resize=[
  {
     description=>'Горизонтальное фото',
     file=>'<%filename_without_ext%>_mini1.<%ext%>',
     size=>'200x0',
     quality=>'90',
     composite_file=>'./files/watermark/200x0.png',
     composite_gravity=>'center'

  },
  {
     description=>'Горизонтальное фото',
     file=>'<%filename_without_ext%>_mini2.<%ext%>',
     size=>'800x0',
     quality=>'90',
     composite_file=>'./files/watermark/800x0.png',
     composite_gravity=>'center'


  },
  {
     description=>'Горизонтальное фото',
     file=>'<%filename_without_ext%>_mini3.<%ext%>',
     size=>'1200x0',
     composite_file=>'./files/watermark/1200x0.png',
     composite_gravity=>'center',
     quality=>'90'
  },

];
use gigachat;
use JSON;
$form={
  title => 'Статьи',
  work_table => 'article',
  work_table_id => 'id',
  make_delete=>0,
  not_create=>1,
  read_only=>1,
  header_field=>'header',
  default_find_filter => 'header',

  GROUP_BY=>'wt.id',
  AJAX=>{
    in_ext_url=>sub{
      my $s=shift; my $values=shift;
      my $url='';

      sub check_exists_url{
        my $s=shift; my $url=shift; my $postfix=shift;
        return if(!$url);
        if($postfix){
          $url.='-'.$postfix
        }
        #print "url: $url\n";
        return $s->{db}->query(
          query=>'select count(*) from in_ext_url where ext_url=?',
          values=>$url,
          onevalue=>1
        );
      }
      if($values->{rubric_id}){
        my $rub_header=$s->{db}->query(
          query=>'SELECT header from article_rubric where id=?',values=>[$values->{rubric_id}],
          onevalue=>1
        );
        if($rub_header){
          $url.='/'.to_translit($rub_header)
        }
      }
      if($values->{header}){
        $values->{header}=~s/\//-/g;
        $url.=to_translit('/'.$values->{header})
      }
      $url=~s/[^a-zA-Z0-9\-\/]+/-/g;
      $url=~s/\/-/\//; $url=~s/-$//;
      $url=~s/--+/-/g; $url=~s/-$//;
      $url=lc($url);
      if(check_exists_url($s,$url)){
        my $postfix=2;
        while(check_exists_url($s,$url,$postfix)){
          $postfix++
        }
        $url=$url.='-'.$postfix;
      }
      return [
        in_ext_url=>{
          #value=>$url
          instead_of_empty=>$url
        }
      ]
    },
    # ===========================================
    # for_wysiwyg
    remove_all_styles=>sub{
        my $s=shift; my $v=shift;
        my $body=$v->{body};
        $body=~s/\s(class|style)=".+?"//gs;
        $body=~s/\s(class|style)='.+?'//gs;
        return [
            'body',{value=>$body}
        ]
    },
    remove_all_tags=>sub{
      my $s=shift; my $v=shift;
      my $body=$v->{body};
      $body=~s/<div>(.+?)<\/div>/$1\n/gs;
      $body=~s/<h1>(.+?)<\/h1>/$1\n/gs;
      $body=~s/<h2>(.+?)<\/h2>/$1\n/gs;
      $body=~s/<h3>(.+?)<\/h3>/$1\n/gs;
      $body=~s/<h4>(.+?)<\/h4>/$1\n/gs;
      $body=~s/<h5>(.+?)<\/h5>/$1\n/gs;
      $body=~s/<h6>(.+?)<\/h6>/$1\n/gs;
      $body=~s/<h7>(.+?)<\/h7>/$1\n/gs;
      $body=~s/<p>(.+?)<\/p>/$1\n/gs;
      $body=~s/<.*?>//gs;
      $body=~s/\n\n+/\n/gs;
      $body=~s/(.*?)\n/<p>$1<\/p>/gs;
      return [
        'body',{value=>"777$body" }
      ]
    },
    clear_tables=>sub{
        my $s=shift; my $v=shift;
        my $body=$v->{body};
        sub clean_table{
            my $table=shift;
            $table=~s/\sstyle=".+?"//gs;
            $table=~s/\sstyle='.+?'//gs;
            $table=~s/\sclass=".+?"//gs;
            $table=~s/\sclass='.+?'//gs;
            return $table
        }
        my $num=0;
        my @tables=();
        while($body=~m/(<table.*?>.+?<\/table>)/gs){
            my $table=$1;
            $tables[$num]=$table;
            $body=~s/<table.*?>.+?<\/table>/[T$num]/s;
            $num++;
        }
        my $num=0;
        foreach my $table (@tables){
            my $table_clean=clean_table($table);
            $body=~s/\[T$num\]/$table_clean/s;
            $num++;
        }

        return [
            'body',{value=>$body}
        ]
    },
    create_anons=>sub{
      my $s=shift; my $v=shift;
      my $query='Отвечай JSON строкой и больше ничего лишнего не пиши. Составь seo оптимизированные тайтл и мета дескрипшен для этой страницы в формате JSON {"title":"...","description":""}:  '.$v->{body};
      $query=~s/<.*?>/ /gs;
      my $result=gigachat::prompt($query);
      my $data=eval {from_json($result)};
      use Data::Dumper;
      #print Dumper({data=>$data});
      my @response=();
      if($data && ref($data) eq 'HASH'){

        if($data->{title}){
          push @response,('header',{value=>$data->{title}});
        }
        if($data->{description}){
          push @response,('anons',{value=>$data->{description}});
        }
      }
      return \@response;
      #[
      #    'anons',{value=>}
      #]
    }

  },
  events=>{
    permissions=>sub{

      if($form->{id}){
        $form->{ov}=$form->{db}->query(
          query=>'select * from article where id=?',
          values=>[$form->{id}],
          onerow=>1
        );
      }


      if($form->{manager}->{permissions}->{admin}){
        $form->{not_create}=0;
        $form->{make_delete}=1;
        $form->{read_only}=0;
      }
      elsif($form->{manager}->{permissions}->{author}){
        
        $form->{not_create}=0;
        $form->{make_delete}=0;

        if($form->{script} eq 'admin_table' || $form->{action}=~m/^(new|insert)$/){
          $form->{read_only}=0;

        }
        elsif($form->{ov}){
          if($form->{manager}->{id}==$form->{ov}->{manager_id}){
            $form->{read_only}=0
          }
        }



      }
      #pre($form->{make_delete});
      #
        #print_header();
        #print "Доступ запрещён!" ; exit;
      #  push @{$form->{errors}},'Доступ запрещён';
      #}
    },
    after_save=>sub{

      if($form->{new_values}->{top} && !$form->{fields_hash}->{top}->{read_only}){
        my $values=$form->{db}->query(
          query=>'select * from article where id=?',
          values=>[$form->{id}],
          onerow=>1
        );
        $form->{db}->query(query=>"UPDATE article set top=0 where id<>?",values=>[$form->{id}]);
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

  # on_filters=>[
  #   {name=>'header',value=>''},
  #   {name=>'anons'},
  #   {name=>'tags'},
  #   {name=>'enabled',value=>[]},
  # ],
  search_on_load=>0,
  fields =>
  [
    {
      description=>'url',
      name=>'in_ext_url',
      type=>'in_ext_url',
      in_url=>'/article/<%id%>',
      # foreign_key=>'project_id',
      # foreign_key_value=>12,
    },

    {
      name => 'header', # наименование поля
      description => 'Название',
      type => 'text',
      full_str=>1,
      filter_on=>1,
      before_code=>sub{
        my $e=shift;
        if($form->{action} eq 'new'){
          $e->{regexp_rules}=[
            q{/^.+$/}=>'Заполните заголовок',
            q{/.{34}/}=>'Заголовок слишком короткий (должен быть не менее 34 символов)',
            q{/^.{34,48}$/}=>'Заголовок слишком длинный (должен быть не более 48 символов)',
          ]
        }
        if($form->{ov}->{in_ext_url}){
          $e->{frontend}->{ajax}=undef;
        }
      },
      frontend=>{
          ajax=>{
            name=>'in_ext_url'
          }
      },
    },

    {
      description=>'Автор',
      table=>'manager',
      type=>'select_from_table',
      name=>'manager_id',
      table=>'manager',
      header_field=>'name',
      value_field=>'id',
      read_only=>1,
      tablename=>'m',

      before_code=>sub{
        my $e=shift;
        
        if($form->{action} eq 'new'){
          $e->{value}=$form->{manager}->{id}
        }

        $e->{read_only}=1;
        if($form->{manager}->{login} eq 'admin'){
          $e->{read_only}=0;
          $e->{make_change_in_search}=1
        }
        elsif($form->{manager}->{permissions}->{author}){
          if($form->{action}=~m/^(new|insert)$/){
            $e->{value}=$form->{manager}->{id};
            $e->{where}='id='.$form->{manager}->{id};
            $e->{read_only}=0;
          }
        }
        #$e->{after_html}=qq{<div style="border: 1px solid black;">$form->{manager}->{login}</div>}

      },
      regexp_rules=>[
        q{/[1-9]/},'Выберите автора',

      ],
      #make_change_in_search=>1
    },
    {
      description=>'Рубрика статьи',
      type=>'select_from_table',
      table=>'article_rubric',
      name=>'rubric_id',
      tablename=>'ar',
      before_code=>sub{
        my $e=shift;
        if($form->{ov}->{in_ext_url}){
          $e->{frontend}->{ajax}=undef;
        }
      },
      frontend=>{
          ajax=>{
            name=>'in_ext_url'
          }
      },
      regexp_rules=>[
        '/[1-9]/','Поле "рубрика" обязательно'
      ]
    },
    {
      description=>'Отображать на сайте',
      type=>'select_values',
      before_code=>sub{
        my $f=shift;
        #ыif($form->{action})


        if(($form->{ov}->{enabled}==2 || $form->{ov}->{enabled}==3) && !$form->{manager}->{permissions}->{adm_kz}){
          $f->{read_only}=1
        }

        # при редактировании запрещаем переводить на kz более 40%


      },
      values=>[
        {v=>'0',d=>'не публиковать нигде'},
        {v=>'1',d=>'публиковать только на yabikupil'},
      ],

      name=>'enabled'
    },
    {
      description=>'Главная новость',
      type=>'switch',
      name=>'top',
      read_only=>1,
      before_code=>sub{
        my $e=shift;
        if($form->{manager}->{permissions}->{admin}){
          $e->{read_only}=0
        }
      }
    },

    {
      name=>'anons',
      description=>'Анонс',
      type=>'textarea',
      full_str=>1,
      style=>'height: 100px',
      frontend=>{
        buttons=>[
          {
            description=>'Анонс на основе текста статьи',
            ajax=>'create_anons',
          }
        ]
      }
    },
    { 
      description=>'Фото', # Фото статьи
      type=>'file',
      name=>'photo',
      filedir=>'./files/article',
      # .accept=>'doc,.docx,.xml,application/msword,application/vnd.openxm
      #accept=>'image/png, image/jpeg',
      #accept=>'image/*',
      crops=>1,
      #required=>1,
      resize=>[
        {
          description=>'Горизонтальное фото',
          file=>'<%filename_without_ext%>_mini2.<%ext%>',
          size=>'1004x490',
          quality=>'90'
        },
        {
          description=>'Вертикальное фото',
          file=>'<%filename_without_ext%>_mini1.<%ext%>',
          size=>'488x1008',
          quality=>'95'
        },
        {
          description=>'Квадратное фото',
          file=>'<%filename_without_ext%>_mini3.<%ext%>',
          size=>'500x500',
          quality=>'95'
        },
        {
          description=>'Фото для страницы статьи',
          file=>'<%filename_without_ext%>_mini4.<%ext%>',
          size=>'1165x672',
          quality=>'90'
        },
      ]
    },
    { 
      description=>'Фотогалерея1', # Галерея1
      name=>'galery',
      type=>'1_to_m',
      table=>'article_photos1',
      table_id=>'id',
      foreign_key=>'article_id',
      sort=>1,
      view_type=>'list',
      fields=>[
        {
          description=>'Наименование',
          name=>'header',
          type=>'text'
        },
        {
          description=>'Фото',
          type=>'file',
          filedir=>'./files/article_galery1',
          name=>'photo',
          preview=>'100x0',
          resize=>$galery_resize
        }
      ]
    },
    { 
      description=>'Фотогалерея2', # Галерея2
      name=>'galery2',
      type=>'1_to_m',
      table=>'article_photos2',
      table_id=>'id',
      foreign_key=>'article_id',
      sort=>1,
      view_type=>'list',
      
      fields=>[
        {
          description=>'Наименование',
          name=>'header',
          type=>'text'
        },
        {
          description=>'Фото',
          type=>'file',
          filedir=>'./files/article_galery2',
          name=>'photo',
          preview=>'50x0',
          resize=>$galery_resize
        }
      ]
    },
    { 
      description=>'Фотогалерея3', # Галерея3
      name=>'galery3',
      type=>'1_to_m',
      table=>'article_photos3',
      table_id=>'id',
      foreign_key=>'article_id',
      sort=>1,
      view_type=>'list',
      
      fields=>[
        {
          description=>'Наименование',
          name=>'header',
          type=>'text'
        },
        {
          description=>'Фото',
          type=>'file',
          filedir=>'./files/article_galery3',
          name=>'photo',
          preview=>'50x0',
          resize=>$galery_resize
        }
      ]
    },
    {
      description=>'Фотогалерея4', # Галерея4
      name=>'galery4',
      type=>'1_to_m',
      table=>'article_photos4',
      table_id=>'id',
      foreign_key=>'article_id',
      sort=>1,
      view_type=>'list',

      fields=>[
        {
          description=>'Наименование',
          name=>'header',
          type=>'text'
        },
        {
          description=>'Фото',
          type=>'file',
          filedir=>'./files/article_galery4',
          name=>'photo',
          preview=>'50x0',
          resize=>$galery_resize
        }
      ]
    },
    {
      description=>'Фотогалерея5', # Галерея4
      name=>'galery5',
      type=>'1_to_m',
      table=>'article_photos5',
      table_id=>'id',
      foreign_key=>'article_id',
      sort=>1,
      view_type=>'list',

      fields=>[
        {
          description=>'Наименование',
          name=>'header',
          type=>'text'
        },
        {
          description=>'Фото',
          type=>'file',
          filedir=>'./files/article_galery5',
          name=>'photo',
          preview=>'50x0',
          resize=>$galery_resize
        }
      ]
    },
    {
      description=>'Фото2 подробного описания статьи',
      type=>'file',
      name=>'photo_in',
      filedir=>'./files/article',
      # crops=>1,
      # resize=>[
      #   {
      #     description=>'Горизонтальное фото',
      #     file=>'<%filename_without_ext%>_mini2.<%ext%>',
      #     size=>'518x300',
      #     quality=>'90'
      #   },

      # ]
    },
    {
      name => 'body',
      description => 'Текст',
      full_str=>1,
      type => 'wysiwyg',
      frontend=>{
        buttons=>[
            {
                description=>'Удалить все стили и классы',
                ajax=>'remove_all_styles',
            },
            {
                description=>'Очистить таблицы',
                ajax=>'clear_tables'
            },
            {
                description=>'Очистить структуру',
                ajax=>'remove_all_tags',
            },
        ],
      },
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
      not_clear=>1,
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
