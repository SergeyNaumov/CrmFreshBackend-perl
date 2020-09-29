$form={
  title=>'Отчёты',
  work_table=>'master',
  table_id=>'id',
  read_only=>1,
  make_delete=>0,
  not_create=>1,
  events=>{
    before_search=>sub{
      my $SF=$form->{query_search}->{SELECT_FIELDS};
      my $tables_str=join('',@{$form->{query_search}->{TABLES}});
      my $where_str='';

      if(scalar(@{$form->{query_search}->{WHERE}})){
        $where_str='WHERE '.join(' AND ',@{$form->{query_search}->{WHERE}});
      }

      my $query=qq{SELECT m.header, count(*) cnt, sum(if(wt.is_ok=1,1,0)) cnt_ok, sum(if(wt.is_ok=0,1,0)) cnt_not_ok FROM $tables_str $where_str GROUP BY m.id ORDER BY m.header};
      my $list=$form->{db}->query(query=>$query);
      
      my $report_table=$s->template({
        template=>'./conf/report.conf/table.html',
        vars=>{
          LIST=>$list,
          dp=>$form->{query_search}->{on_filters_hash}->{dat_pov}
        }
      });
      push @{$form->{out_before_search}},$report_table;
      # не выводим результат поиска
      $form->{not_out_result_search}=1;
    }
  },
  QUERY_SEARCH_TABLES=>
  [
    {table=>'work',alias=>'wt'},
    {table=>'master',alias=>'m',link=>'wt.master_id=m.id',left_join=>1},
  ],
  fields=>[
      {
        name => 'dat_pov', 
        description => 'Дата поверки',
        type => 'date',
        filter_on=>1,
        before_code=>sub{
          my $e=shift;
          if($form->{script} eq 'admin_table'){
            $form->{on_filters}->[0]->{value}=[cur_date(-1),cur_date(-1)];
          }
        },
        not_order=>1,
        frontend=>{ajax=>{name=>'calc_dat_pov_next'}},
        tab=>'c1'
      },
      {
        description=>'Мастер',
        name=>'master_id',
        type=>'select_from_table',
        tablename=>'m',
        table=>'master',
        header_field=>'header',
        value_field=>'id'
      },
      {
        name => 'is_ok',
        description => 'Годен/не годен',
        type => 'select_values',
        before_code=>sub{
          my $e=shift;
          if($form->{action} eq 'new'){
            $e->{value}=1
          }
        },
        values=>[
          {v=>0,d=>'не годен'},
          {v=>1,d=>'годен'},
        ],
        tab=>'c2',
        frontend=>{ajax=>{name=>'calc_dat_pov_next'}},
        filter_on=>1
      },
    
  ]
};