$form={
  title => 'Комментарии в детализации платежей',
  work_table => 'bill_part_comment',
  work_table_id => 'id',
  make_delete => '1',
  header_field=>'header',
  default_find_filter=>'<%header%>',
  sort_field=>'sort',
  tree_use=>0,
  sort=>1,
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
