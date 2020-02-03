$ENV{REMOTE_USER}='admin' if($ENV{REMOTE_USER} eq 'admin');

$form={
	title => 'Отчёт',
	work_table => 'user_contact',
	work_table_id => 'id',
	make_delete => '0',
	default_find_filter => 'firm,next_contact,manager_id',
	read_only => '1',
  not_edit=>1,
  not_create=>1,
  #explain=>1,
  #explain_exit=>1,
	make_delete=>0,
	#explain=>1,
	tree_use => '0',
  perpage=>5000,
  javascript=>{
    
  },
  # QUERY_SEARCH_TABLES=>
  #   [
  #     {table=>'report1',alias=>'wt',},
  #     {table=>'manager',alias=>'m',link=>'wt.manager_id = m.id', left_join=>1},
  #     {table=>'user',alias=>'u',link=>'wt.user_id = u.id',left_join=>1},
  #   ],
  QUERY_SEARCH=>q{
      SELECT 
        *
      FROM
      (
        (
          SELECT
            wt.id wt__id,2 wt__type,wt.manager_id wt__manager_id,wt.registered wt__registered,'' wt__duration,
            wt.user_id wt__user_id, concat_ws(' ',wt.registered,wt.body) wt__body,'' wt__phone,
            m.name m__name, u.firm u__firm, u.id u__id
          FROM
            user_memo wt
            JOIN manager m ON (wt.manager_id=m.id)
            JOIN user u ON (wt.user_id=u.id)
            <WHERE_MEMO>
        )
        UNION
        (
          SELECT
            wt.uid wt__id, 1 wt__type, wt.manager_id wt__manager_id, wt.start wt__registered, wt.duration wt__duration,
            wt.user_id wt__user_id,'' wt__body,wt.client wt__phone,
            m.name m__name, u.firm u__firm, u.id u__id
          FROM
          call_history wt
          LEFT JOIN manager m ON (wt.manager_id=m.id)
          LEFT JOIN user u ON (wt.user_id=u.id)
            <WHERE_CALL>
        )

      ) as wt <WHERE_ALL>
  },
  plugins => [
     'find::to_xls'
  ],
  run=>{
    sec_to_time=>sub{
      my ($h,$m,$s)=(0,0,0);
      $s=shift;
      if($s>3600){
        $h=int($s/3600);
        $s=$s-$h*3600;
      }
      if($s>60){
        $m=int($s/60);
        $s=$s-$m*60;
      }
      return sprintf("%02d:%02d:%02d",$h,$m,$s);
    }
    #get_group_from_manager=>sub{
    #  my $m=shift;
    #  my $sth=$form->{dbh}->prepa
    #}
  },
  #not_order=>1,
	events=>{
		permissions=>[
      sub{ # доступ в карту
        

      },
      
      
    ],
    before_search_mysql=>sub{
      my $where_call=$form->{where_list};
      my $where_memo=$where_call;
      my $where_all='';
      $where_call=~s{wt\.registered}{wt\.start}gs;
      
      $where_call='WHERE '.$where_call if($where_call=~m{\S});
      $where_memo='WHERE '.$where_memo if($where_memo=~m{\S});
      
      my $type=param('type');
      if($type=~m{^(1|2)$}){
        $where_all=qq{WHERE wt__type=$type};
      }
      
      $where_call=~s{wt.type IN \(.+?\)}{}g; $where_call=~s{AND\s+AND}{AND}g;
      $where_memo=~s{wt.type IN \(.+?\)}{}g; 
      $where_memo=~s{\(\s*wt.duration.+?\)}{}g; 
      $where_memo=~s{AND\s+AND}{AND}g;
      $where_memo=~s{AND\s+$}{}g;
      
      $form->{QUERY_SEARCH}=~s/<WHERE_MEMO>/$where_memo/gs;
      $form->{QUERY_SEARCH}=~s/<WHERE_CALL>/$where_call/gs;
      $form->{QUERY_SEARCH}=~s/<WHERE_ALL>/$where_all/gs;

      $form->{NOT_WHERE}=1;
      $form->{sortstring}=~s{wt\.registered}{wt__registered}gs;
      $form->{sortstring}=~s{m\.name}{m__name}gs;
      $form->{sortstring}=~s{wt\.type}{wt__type}gs;
      $form->{sortstring}=~s{wt\.phone}{wt__phone}gs;
      $form->{sortstring}=~s{wt\.duration}{wt__duration}gs;
      $form->{sortstring}=~s{u\.firm}{u__firm}gs;
      #pre($form->{sortstring}); exit;
      #$form->{sortstring}='ORDER BY wt__registered';
      #$form->{explain}=1;
    }
    #before_search=>sub{

      #my $manager_id=param('manager_id');
      #my $dt_disabled=param('filter_dt_disabled');
      #my @where_calls; my @where_comments;
      #my $manager_id=param('manager_id');
      #my $type=param('type');
      #if($dt_disabled ne '1'){
        #my $dt_low=param('dt_low');
        #my $dt_hi=param('dt_hi');
        
        #if($dt_low=~m{^\d+-\d+-\d+(\s+\d+:\d+:\d+)?$}){
          #push @where_calls,qq{wt.start>='$dt_low'};
          #push @where_comments,qq{wt.registered>='$dt_low'};
          
        #}
        #if($dt_hi=~m{^\d+-\d+-\d+(\s+\d+:\d+:\d+)?$}){
          #push @where_calls,qq{wt.start<='$dt_hi'};
          #push @where_comments,qq{wt.registered<='$dt_hi'}
          
        #}
      #}
      #my ($calls_list,$comment_list,$list);
      #if($manager_id=~m{^\d+$}){
        #push @where_calls,qq{wt.manager_id=$manager_id};
        #push @where_comments, qq{wt.manager_id=$manager_id};
      #}
      
      ## ======
      #if(!param('type')){ # Единым списком
          #my $call_query=q{
            #SELECT 
              #1 type, 
              #m.name, wt.start registered, wt.duration,
              #wt.user_id,u.firm,'' body,wt.client phone
            #FROM
              #call_history wt
              #JOIN manager m ON wt.manager_id=m.id
              #LEFT JOIN user u ON u.id=wt.user_id
          #};
          #if(scalar(@where_calls)){
            #$call_query.=' WHERE '.join(' AND ',@where_calls)
          #}
          
          #my $comment_query=q{
            #SELECT
              #2 type, m.name, wt.registered, '' duration,
              #wt.user_id, u.firm, wt.body, '' phone
            #FROM
              #user_memo wt
              #LEFT JOIN user u ON u.id=wt.user_id
              #JOIN manager m ON m.id=wt.manager_id
              
          #};
          
          #if(scalar(@where_comments)){
            #$comment_query.=' WHERE '.join(' AND ',@where_comments)
          #}
          #my $query=qq{
            #SELECT * FROM
            #(
              #$call_query
                #UNION
              #$comment_query
            #) x
            #ORDER BY registered
          #};
          
          #my $sth=$form->{dbh}->prepare($query);
          #$sth->execute();
          #$list=$sth->fetchall_arrayref({});
          
          #foreach my $l (@{$list}){
            #$l->{duration}=&{$form->{run}->{sec_to_time}}($l->{duration});
          #}

      #}
      #else{ # Раздельными списками
          ## 1. Звонки
          #my $call_query=q{
            #SELECT 
              #wt.*,
              #m.name,
              #u.firm
            #FROM
              #call_history wt
              #JOIN manager m ON wt.manager_id=m.id
              #LEFT JOIN user u ON u.id=wt.user_id
          #};
          #if(scalar(@where_calls)){
            #$call_query.=' WHERE '.join(' AND ',@where_calls)
          #}
          #$call_query.=q{ ORDER BY wt.start};
          #my $sth=$form->{dbh}->prepare($call_query);
          #$sth->execute();
          #$calls_list=$sth->fetchall_arrayref({});
          #foreach my $l (@{$calls_list}){
            #$l->{duration}=&{$form->{run}->{sec_to_time}}($l->{duration});
          #}
          ## 2. Комментарии
          #my $comment_query=q{
            #SELECT
              #wt.*,m.name,u.firm
            #FROM
              #user_memo wt
              #JOIN manager m ON m.id=wt.manager_id
              #LEFT JOIN user u ON u.id=wt.user_id
          #};
          
          #if(scalar(@where_comments)){
            #$comment_query.=' WHERE '.join(' AND ',@where_comments)
          #}
          #$comment_query.=q{ ORDER BY wt.registered};
          #$sth=$form->{dbh}->prepare($comment_query);
          #$sth->execute();
          #$comment_list=$sth->fetchall_arrayref({});
      #}

      
      ##pre(\@where_calls); exit;

      
      
      #template({
            #template=>'./conf/report.conf/report.tmpl',
            #vars=>{
                #calls_list=>$calls_list,
                #comment_list=>$comment_list,
                #list=>$list,
                #type=>$type
            #},
            #print=>1
      #});
      #exit;

    #},
	},
	fields=>[
        {
          description=>'Дата и время события',
          name=>'registered',
          type=>'datetime',
          filter_on=>1
        },
        {
          description=>'Тип',
          name=>'type',
          type=>'select_values',
          values=>[{v=>1,d=>'звонок'},{v=>2,d=>'комментарий'}],
          filter_on=>1
        },
        {
          description=>'Сотрудник',
          type=>'select_from_table',
          table=>'manager',
          tablename=>'m',
          name=>'manager_id',
          header_field=>'name',
          value_field=>'id',
          filter_on=>1
        },
        {
          description=>'Продолжительность, сек',
          type=>'text',
          filter_type=>'range',
          name=>'duration',
          filter_on=>1,
          filter_code=>sub{
            my $v=$_[0]->{str}->{wt__duration};
            &{$form->{run}->{sec_to_time}}($v);
          }
        },
        {
          description=>'Организация',
          type=>'select_from_table',
          name=>'user_id',
          table=>'user',
          tablename=>'u',
          header_field=>'firm',
          value_field=>'id',
          autocomplete=>1,
          filter_on=>1,
          filter_code=>sub{
            my $e=shift;
            return 'не известно: '.$e->{str}->{wt__client}.'' unless($e->{str}->{u__id});
            $e->{str}->{u__firm}='-' unless($e->{str}->{u__firm});
            return $s->{u__firm} if(param('plugin'));
            return qq{<a href="./edit_form.pl?config=user&action=edit&id=$e->{str}->{u__id}" target="_blank">$e->{str}->{u__firm}</a>}
          },
        },
        {
          description=>'Комментарий',
          type=>'text',
          name=>'body',
          not_order=>1,
          filter_on=>1
        },
        {
          description=>'Телефон',
          type=>'text',
          name=>'phone',
          filter_on=>1
        },        

	]
};
