#$ENV{REMOTE_USER}='admin' if($ENV{REMOTE_USER} eq 'admin');
use lib './lib';
use coresubs;

$form={
	title => 'уведомления по счетам',
	work_table => 'bill_notification',
	work_table_id => 'id',
	make_delete => '1',
	
	read_only => '1',
	make_delete=>0,
	not_create=>1,
	tree_use => '0',
  GROUP_BY=>'wt.id',
  QUERY_SEARCH_TABLES=>
    [
      {table=>'bill_notification',alias=>'wt'},
  ],
	events=>{
		permissions=>[
      sub{
        if($form->{manager}->{permissions}->{bill_notification}){
          $form->{read_only}=0;
          $form->{make_delete}=1;
          $form->{not_create}=0;
        }
      }
    ],

	},
	fields=>[
    {
      description=>'Тема письма',
      type=>'text',
      name=>'header',
    },
    {
      description=>'Тело письма',
      type=>'wysiwyg',
      name=>'body',
    },
    {
      description=>'За сколько дней до окончания отправлять',
      type=>'text',
      name=>'count_days'
    }
	]
};
