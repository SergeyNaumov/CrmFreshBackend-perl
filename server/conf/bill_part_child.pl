use send_mes;
use core_strateg;
$form={
	title => 'Раcходы',
	work_table => 'bill',
	work_table_id => 'id',
  make_delete => 0,
  not_create=>1,
  read_only=>1,
  not_edit=>1,
	default_find_filter => 'header',
	tree_use => '0',
	events=>{
		permissions=>sub{
      if(
          #$form->{manager}->{permissions}->{view_all_paids} || 
          $form->{manager}->{permissions}->{admin_paids} || 
          $form->{manager}->{login} eq 'admin')
      { # разрешаем видеть все платежи

      }
      else{
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
        if(param('order_summ')){
          push @select_fields,'sum(wt.summ) wt_summ';
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
            push @{$form->{out_before_search}},qq{Сумма расходной части: $s->{wt_summ}};  
          }
          #pre($s);
          #pre($form->{out_before_search});
        }
      
    }
	},
  QUERY_SEARCH_TABLES=>
  [
      {table=>'bill_part_child',alias=>'wt'},
      {table=>'bill_part',alias=>'bp',link=>'bp.id=wt.parent_id'},
      {table=>'bill',alias=>'b',link=>'b.id=bp.bill_id',left_join=>1},
      {table=>'manager_full',alias=>'bm',link=>'b.manager_id=bm.id',left_join=>1},
      {table=>'manager_group',alias=>'bmg',link=>'bmg.id=bmg.id',for_fields=>['bmg_id'],left_join=>1},
      
      {table=>'docpack',alias=>'dp',link=>'b.docpack_id=dp.id',left_join=>1},
      {table=>'user',alias=>'u',link=>'dp.user_id=u.id',left_join=>1},
      #{table=>'manager',alias=>'m',link=>'m.id=wt.manager_id',left_join=>1},
      #{table=>'manager_group',alias=>'mg',link=>'m.group_id=mg.id',left_join=>1},
      #{table=>'ur_lico',alias=>'ul',link=>'ul.id=dp.ur_lico_id',left_join=>1,for_fields=>['ur_lico_id']},
      
  ],
  #explain=>1,
  plugins => [
      'find::to_xls'
  ],
  GROUP_BY=>'wt.id',
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
      description=>'Сумма счёта',
      type=>'filter_extend_text',
      filter_type=>'range',
      tablename=>'b',
      name=>'b_summ',
      db_name=>'summ'
    },
    {
      description=>'Менеджер счёта',
      type=>'filter_extend_select_from_table',
      table=>'manager',
      header_field=>'name',
      name=>'b_manager_id',
      tablename=>'bm'
    },
    {
      description=>'Группа менеджера счёта',
      type=>'filter_extend_select_from_table',
      table=>'manager_group',
      header_field=>'header',
      name=>'bmg_id',
      tablename=>'bmg'
    },
    {
      description=>'Дата оплаты',
      name=>'paid_date',
      type=>'filter_extend_date',
      tablename=>'b',
      default_off=>1,
    },
    {
      description=>'Расходная часть',
      type=>'text',
      name=>'summ',
      filter_type=>'range'
    },
    {
      description=>'Сумма разделения',
      type=>'filter_extend_text',
      filter_type=>'range',
      tablename=>'bp',
      name=>'sum'
    },
    {
      description=>'% Доходности',
      name=>'profitability',
      tablename=>'bp',
      filter_type=>'range',
      #filter_code=>sub{
      #  my $s=$_[0]->{str};
      #  return $s->{bp__profitability};
      #}
    },
    {
      description=>'Комментарий',
      type=>'text',
      name=>'comment'
    },
    {
      description=>'Комментарий разделения',
      type=>'filter_extend_text',
      name=>'comment_txt',
      tablename=>'bp'
    },
	]
};
