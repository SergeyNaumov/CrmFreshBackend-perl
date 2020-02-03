use send_mes;
use core_strateg;
$form={
	title => 'Ведомость (разделения оплат)',
	work_table => 'bill',
	work_table_id => 'id',
	make_delete => 0,
  not_create=>1,
  read_only=>1,
  not_edit=>1,
	default_find_filter => 'header',
	tree_use => '0',
  #explain=>'1',
	events=>{
		permissions=>sub{
      my $manager=$form->{manager};
      if( # Разрешаем доступ только администратору платежей
          !$manager->{permissions}->{admin_paids} && !$manager->{permissions}->{bill_part_only_me} &&
          $manager->{login} ne 'admin'
      ){
        print_header();
        print "Доступ запрещён!";
        exit;
      }

      if(
          #$form->{manager}->{permissions}->{view_all_paids} || 
          $manager->{permissions}->{admin_paids} || 
          $manager->{login} eq 'admin'
      )
      { # разрешаем видеть все платежи

      }
      elsif($manager->{permissions}->{view_all_paids}){

      }
      else{
        #pre($form->{manager});
        my @chld=@{$form->{manager}->{owner_groups}};
        if(scalar @chld){
          $form->{add_where}='bm.group_id IN ('.join(',',@chld).')';
        }
        else{
          $form->{add_where}=qq{b.manager_id=$form->{manager}->{id}};
        }
      }
      
		},
    before_search=>sub{
      my %arg=@_;
      
        my @select_fields=();
        if(param('order_sum')){
          push @select_fields,'sum(wt.sum) wt_sum';
        }
        if(param('order_expense')){
          push @select_fields,'sum(wt.expense) wt_expense';
        }
        if(param('order_profitability_rub')){
          #my $query_profitability_summ=qq{
          #SELECT sum(summ) FROM bill_part where id IN
          #    (
          #      SELECT wt.id from $arg{tables} }.($arg{where}?"WHERE $arg{where}":'').q{
          #    )
          #};
          # wt.sum*wt.profitability/100
          push @select_fields,'round(sum(wt.sum*wt.profitability/100),2) wt_profitability_rub'; 
        }

        if(param('order_b_summ')){
          my $query_bill_summ=qq{
            SELECT sum(summ) FROM bill where id IN
              (
                SELECT b.id from $arg{tables} }.($arg{where}?"WHERE $arg{where}":'').q{
              )
          };
          my $sth=$form->{dbh}->prepare($query_bill_summ);
          $sth->execute();
          my $s=$sth->fetchrow();
          if($s){
            push @{$form->{out_before_search}},qq{Сумма счетов: $s};
          }
        }
        #pre(\@select_fields);
        if(scalar(@select_fields)){
          my $query=q{
            SELECT
              }.join(',',@select_fields).qq{
            FROM
              $arg{tables}
            }.($arg{where}?"WHERE $arg{where}":'');
            #pre($query);
          my $sth=$form->{dbh}->prepare($query);
          $sth->execute();
          my $s=$sth->fetchrow_hashref;

          if($s->{wt_sum}){
            push @{$form->{out_before_search}},qq{Сумма из разделений: $s->{wt_sum}}; 
          }
          if($s->{wt_profitability_rub}){
            push @{$form->{out_before_search}},qq{Доходность, руб: $s->{wt_profitability_rub}}; 
          }
          
          if($s->{wt_expense}){
            push @{$form->{out_before_search}},qq{Сумма расходной части: $s->{wt_expense}};  
          }
          #pre($s);
          #pre($form->{out_before_search});
        }
      
    }
	},
  QUERY_SEARCH_TABLES=>
  [
      {table=>'bill_part',alias=>'wt'},
      {table=>'bill_part_comment',alias=>'bpc',link=>'wt.comment_id=bpc.id',left_join=>1,for_fields=>['comment_id']},
      {table=>'bill',alias=>'b',link=>'b.id=wt.bill_id'},
      {table=>'manager_full',alias=>'bm',link=>'b.manager_id=bm.id'},
      {table=>'manager_group',alias=>'bmg',link=>'bmg.id=bm.group_id',for_fields=>['bmg_id','b_manager_id']},
      {table=>'docpack',alias=>'dp',link=>'b.docpack_id=dp.id',left_join=>1},
      {table=>'ur_lico',alias=>'ul',link=>'dp.ur_lico_id=ul.id', left_join=>1},
      {table=>'user',alias=>'u',link=>'dp.user_id=u.id',left_join=>1},
      #{table=>'manager',alias=>'m',link=>'m.id=wt.manager_id',left_join=>1},
      #{table=>'manager_group',alias=>'mg',link=>'m.group_id=mg.id',left_join=>1},
      #{table=>'ur_lico',alias=>'ul',link=>'ul.id=dp.ur_lico_id',left_join=>1,for_fields=>['ur_lico_id']},
      
  ],
  #add_where=>'bp.id=28',
  plugins => [
      'find::to_xls'
  ],
  debug=>1,
  GROUP_BY=>'wt.id,b.id',
  filter_list_order=>[
    'paid_date','b_summ','sum','profitability_rub','profitability','expense','firm','b_manager_id','bmg_id',
    'comment_id','ul_firm'
  ],
	fields =>
	[
    {
      description=>'Название компании',
      name=>'firm',
      type=>'filter_extend_text',
      tablename=>'u',
      filter_on=>1,
      filter_code=>sub{
        my $s=$_[0]->{str};
        return $s->{u__firm} if(param('plugin'));
        my $out=qq{<a href="./edit_form.pl?config=user&action=edit&id=$s->{u__id}" target="_blank">$s->{u__firm}</a>};
        #if(){
        $out.=qq{
            <div style="margin-top: 10px; margin-bottom: 10px;"><a href="/tools/paid_division_parts.pl?bill_id=$s->{b__id}" target="_blank">разделения</a></div>
          };
        #}
        return $out;
        
      },
      filter_on=>1
    },
    {
      description=>'Дата оплаты',
      name=>'paid_date',
      type=>'filter_extend_date',
      tablename=>'b',
      default_off=>1,
    },
    {
      description=>'Менеджер счёта',
      type=>'filter_extend_select_from_table',
      table=>'manager',
      header_field=>'name',
      name=>'b_manager_id',
      tablename=>'bm',
      db_name=>'id'
    },
    {
      description=>'Группа менеджера счёта',
      type=>'filter_extend_select_from_table',
      table=>'manager_group',
      header_field=>'header',
      name=>'bmg_id',
      db_name=>'id',
      tablename=>'bmg'
    },
    {
      description=>'Сумма счёта',
      type=>'filter_extend_text',
      filter_type=>'range',
      tablename=>'b',
      name=>'b_summ',
      db_name=>'summ'
    },
    {
      description=>'Сумма разделения',
      name=>'sum',
      filter_type=>'range',
    },
    {
      description=>'Доходность, руб',
      type=>'text',
      name=>'profitability_rub',
      filter_type=>'range',
      #not_order=>1,
      tablename=>'wt',
      db_name=>'func::(ROUND(wt.sum*wt.profitability/100,2))'
    },
    {
      description=>'% Доходности',
      name=>'profitability',
      filter_type=>'range',
    },
    {
      description=>'Расходная часть',
      name=>'expense',
      filter_type=>'range',
    },
    {
      description=>'Комментарий',
      type=>'filter_extend_select_from_table',
      table=>'bill_part_comment',
      tablename=>'bpc',
      name=>'comment_id',
      db_name=>'id'

    },
    {
        description=>'Юр.Лицо',
        #sql=>q{select id,concat(firm,' ',comment) from ur_lico order by header},
        type=>'filter_extend_select_from_table',
        tablename=>'ul',
        table=>'ur_lico',
        name=>'ul_firm',
        db_name=>'id',
    },
    #{
    #  description=>'Комментарий разделения',
    #  type=>'text',
    #  name=>'comment_txt',
    #},
	]
};
