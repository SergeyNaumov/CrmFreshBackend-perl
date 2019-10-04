$form={
	title => 'Регионы',
	work_table => 'region',
	work_table_id => 'id',
	make_delete => '1',
  header_field=>'header',
  default_find_filter => 'header',
  sort_field=>'header',
	tree_use => '1',
	events=>{
		permissions=>sub{
      
      #print Dumper($form->{manager}->{permissions});
			if(($form->{manager}->{permissions}->{content} || $form->{manager}->{login} eq 'admin') ){
				
			}
      else{
        #print_header();
        #print "Доступ запрещён!" ; exit;
        
        
        push @{$form->{errors}},'Доступ запрещён!';

      }
      #use Data::Dumper;
      #push @{$form->{errors}},'Доступ запрещён!';
      #return Dumper($form->{errors})."\n";
		}
	},
  #explain=>1,
	fields =>
	[
    {
      description=>'Страна',
      name=>'country_id',
      type=>'select_from_table',
      table=>'country',
      header_field=>'header',
      value_field=>'id',
      filter_on=>1
    },
		{
			name => 'header',
			description => 'Название',
			type => 'text',
      filter_on=>1
		},
    
    {
      description=>'Временная зона',
      name=>'timeshift',
      type=>'text',
      filter_on=>1
    }
	]
};
