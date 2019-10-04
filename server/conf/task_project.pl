#$ENV{REMOTE_USER}='admin' if($ENV{REMOTE_USER} eq 'admin');
use lib './lib';
use coresubs;

$form={
    title => 'Проекты задач',
    work_table => 'task_project',
    work_table_id => 'id',
    make_delete => 0,
    read_only=>1,
    not_create=>1,
    tree_use => '0',
  GROUP_BY=>'wt.id',
  javascript=>{
   # include=>['./conf/user.conf/doubles.js'] # проверка на дубли
  },
  search_links=>[
    {link=>'./admin_table.pl?config=task_project',description=>'Проекты для задач',target=>'_blank'},

  ],
  QUERY_SEARCH_TABLES=>
    [
      {table=>'task_project',alias=>'wt'},
      {table=>'manager',alias=>'m',link=>'wt.owner=m.id',left_join=>1}
    ],
  run=>{

  },
    events=>{
        permissions=>[
          sub{ # доступ в карту
            if($form->{manager}->{permissions}->{adm_task_projects}){
              $form->{not_create}=0; $form->{make_delete}=1; $form->{read_only}=0;
            }
          }
        ],
        before_update=>sub{

          #if($form->{new_values}->{registered} ne $form->{old_values}->{registered}){
            
          #}
        },
        after_save=>sub{

        },
        after_insert=>sub{
          #if(!$form->{manager}->{permissions}->{change_manager_all} && !scalar(@{$form->{manager}->{owner_groups}})){ # Если нет прав менять менеджера -- проставляем себя
          #  my $sth=$form->{dbh}->prepare("UPDATE $form->{work_table} set manager_id = ? where id = ?");
          #  $sth->execute($form->{manager}->{id},$form->{id});
          #}
        }
    },
    fields=>[
      {
        description=>'Наименование проекта',
        type=>'text',
        name=>'header',
      },
      {
        description=>'Исполнитель задачи',
        type=>'select_from_table',
        name=>'owner',
        table=>'manager',
        tablename=>'m',
        header_field=>'name',
        value_field=>'id',
      },
    ]
};


