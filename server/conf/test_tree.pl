$form={
    title=>'Тестовое дерево',
    work_table=>'test_tree',
    work_table_id=>'id',
    heade_field=>'header',
    tree_use=>1,
    max_level=>1,
    make_delete=>1,
    sort=>1,
    fields=>[
        {
            description=>'Заголовок',
            type=>'text',
            name=>'header'
        },

    ]
};