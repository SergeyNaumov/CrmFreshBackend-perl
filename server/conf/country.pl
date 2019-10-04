$form={
	title => 'Страны',
	work_table => 'country',
	work_table_id => 'id',
	make_delete => '1',
  header_field=>'header',
  default_find_filter => 'header',
  sort_field=>'header',
	
	events=>{
		permissions=>sub{
			if($form->{manager}->{permissions}->{content} || $form->{manager}->{login} eq 'admin'){
				
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
			name => 'header',
			description => 'Наименование',
			type => 'text',
		},
	]
};
