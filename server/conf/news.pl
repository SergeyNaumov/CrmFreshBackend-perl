$form={
	title => 'Новости',
	work_table => 'news',
	work_table_id => 'id',
	make_delete => '1',
  header_field=>'header',
  default_find_filter => 'header',
  #sort_field=>'header',
	#tree_use => '1',
	events=>{
		permissions=>sub{
			#use Data::Dumper;
			#push @{$form->{log}},Dumper($form->{manager});
			if($form->{manager}->{login} eq 'admin' || $form->{manager}->{permissions}->{content}){
				$form->{not_create}=0;
			}
			else{
				push @{$form->{errors}},'доступ запрещён!';
			}
		}
	},
  #explain=>1,
	fields =>
	[
		{
			name => 'header',
			description => 'Название',
			type => 'text',
		},
		{
			name => 'anons',
			description => 'Краткий текст',
			type => 'wysiwyg',
		},
		{
			name => 'body',
			description => 'Текст',
			type => 'wysiwyg',
		},
    {
      description=>'Дата создания',
      name=>'registered',
      type=>'date',
	  empty_value=>'null',
      before_code=>sub{
        my $e=shift;
		#push @{$form->{log}},"action: $form->{action}; id: $form->{id}\n";
		#if($form->{action}=~m{^(insert|new)$})
        if($form->{action} eq 'insert'){
          $e->{read_only}=0
        }
      }
    }
	]
};
