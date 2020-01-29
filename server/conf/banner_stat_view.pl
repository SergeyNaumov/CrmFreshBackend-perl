$form={
    title=>'Статистика по просмотрам',
    work_table=>'banner_stat_view',
    work_table_id=>'id',
    make_delete=>0,
    read_only=>1,
    events=>{
      permissions=>sub{
        if($form->{id}){
          
          #$form->{ov}=$form->{db}->query(query=>'SELECT * from manager_menu where id=?',values=>[$form->{id}],onerow=>1);
        }
      }
    },
    default_find_filter=>'header',
    QUERY_SEARCH_TABLES=>[
      {t=>'banner_stat_view',a=>'wt'},
      {t=>'banner',a=>'b',l=>'wt.banner_id=b.id'},
      {t=>'banner_place',a=>'bp',l=>'wt.banner_place_id=bp.id'},
    ],
    fields=>[
          {
              description=>'Баннер',
              type=>'filter_extend_text',
              name=>'header',
              tablename=>'b',
              not_order=>1,
              filter_on=>1
          },

          {
            description=>'Время',
            type=>'datetime',
            name=>'registered'
          },
          {
            description=>'url',
            type=>'text',
            name=>'REQUEST_URI'
          },
          {
            description=>'ip',
            type=>'text',
            name=>'HTTP_X_REAL_IP'
          },
          {
            description=>'откуда пришли',
            type=>'text',
            name=>'HTTP_REFERER'
          },
      

    ]
};