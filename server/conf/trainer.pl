#use lib './lib';
#use core_strateg qw(child_groups);
#use send_mes;
$form={
	title => 'Тренеры',
	work_table => 'manager',
	work_table_id => 'id',
	make_delete => '0',
  not_create=>0,
  read_only=>0,
  header_field=>'name',
  
	default_find_filter => 'login',
	tree_use => '0',
  javascript=>{
    #include=>['./conf/manager.conf/init.js?ns=1']
  },
  unique_keys=>[['login']],
  explain=>0,
  
  run=>{
  },
	events=>{
		permissions=>[
      sub{
        
        if($form->{id}){
          $form->{ov}=$form->{db}->query(
            query=>'select * from '.$form->{work_table}.' where id=?',
            values=>[$form->{id}],
            onerow=>1
          );
          $form->{title}=$form->{ov}->{name};
        }

      },
    ],
    before_delete=>sub{

    },


	},
  # cols=>[ # Модель формы: Колонки / блоки
  #   [ # Колонка1
  #     {description=>'Общая информация',name=>'main'},
  #   ],
  #   [
  #     {description=>'Права',name=>'permissions'},
  #   ]
  # ],
  QUERY_SEARCH_TABLES=>
  [
    {table=>'trainer',alias=>'wt'},
    #{table=>'manager_group',alias=>'mg',link=>'wt.group_id=mg.id',left_join=>1},
  ],
	fields =>
	[
    {
      name => 'name',
      description => 'ФИО',
      type => 'text',
      tab=>'main',
      filter_on=>1
    },
    # {
    #   description=>'Расписание',
    #   type=>'time_table',
    #   name=>'time_table',
    #   interval_minutes=>60,
    #   interval_count=>12,
    #   first_interval=>10,
    #   form_event_name=>'Добавить в расписание',
    #   table=>'trainer_times',
    #   foreign_key=>'trainer_id',
    #   header_field=>'name', # имя в work_table, соответствующее имени того, кто забронировал
    #   active_color=>'#4a30d7', # Цвет, которым отмечаются записи данной карты
    #   busy_color=>'#6f6d78', # цвет, которым отмечены занятые записи
    #   begin_date=>'2021-09-01', # Дата начала расписания
    #   end_date=>'2022-05-01', # Дата окончания расписания
    # }
	]
};



