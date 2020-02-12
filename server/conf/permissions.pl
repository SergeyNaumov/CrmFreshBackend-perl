$form={
  title => 'Права менеджеров',
work_table => 'permissions',
work_table_id => 'id',
header_field=>'header',
default_find_filter => '<%header%>',
make_delete => '0',
read_only => '1',
not_create=>1,
tree_use => '1',
sort=>'1',
max_level=>1,
search_on_load=>1,
events=>{
    permissions=>sub{
        if($form->{manager}->{login} eq 'admin'){
            $form->{make_delete}=1;
            $form->{read_only}=0;
            $form->{not_create}=0,
        }
    },
    after_insert=>sub{
        my $new_pname='rnd_'.$s->gen_pas(12);
        $form->{db}->query(
            query=>"UPDATE permissions set pname='$new_pname' where id=$form->{id}"
        );
    }
},
fields =>
[
    {
        description=>'Наименование',
        name=>'header',
        type=>'text',
        filter_on=>1
    },
    {
        description=>'Ключевое название',
        name=>'pname',
        type=>'text',
        filter_on=>1,
        uniquew=>1,

    }
]
};
