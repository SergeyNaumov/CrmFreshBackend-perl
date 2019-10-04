$form={
	title => 'Отрасли',
	work_table => 'otr',
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
        #print_header();
        #print "Доступ запрещён!" ; exit;
        push @{$form->{errors}},"Доступ запрещён!";
      }
		}
	},
  #explain=>1,
	fields =>
	[
		{
			name => 'header',
			description => 'Наименование отрасли',
			type => 'text',
            filter_on=>1,
		},
	]
};
