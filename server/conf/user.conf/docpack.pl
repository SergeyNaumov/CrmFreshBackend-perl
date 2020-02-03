# docpack
{
  #description=>'Посмотреть все счета',
  name=>'bill_search',
  type=>'code',
  code=>sub{
    #return '' unless($form->{id});

    return qq{
    <a target="_blank" href="/find_objects.pl?config=bill&f_user_id=$form->{id}&order_f_user_id=10&order_number=11&order_summ=12&order_comment=13&order_registered=14&registered_low=2018-01-22&registered_hi=2018-01-22&filter_registered_disabled=1&order_paid_date=15&paid_date_low=2018-01-22&paid_date_hi=2018-01-22&filter_paid_date_disabled=1&order_paid_to=16&paid_to_low=2018-01-22&paid_to_hi=2018-01-22&filter_paid_to_disabled=1&order_group_id=17&order_manager_id=18">
      Посмотреть все счета
    </a>};
  },
  tab=>'docpack',
},
{
  #description=>'Пакеты документов',
  type=>'docpack',
  name=>'docpack',
  tab=>'docpack',
  before_code=>sub{
    my $e=shift;
    #$e->{before_html}=Dumper($form->{values});
    
  },
  bill_number_rule=>sub{
    my $f=shift; my $dogovor_id=shift;
    my $company_role=($form->{old_values}->{company_role}==2)?'З':'П';
    
    my $item=$form->{db}->query(
      query=>q{SELECT if(max(number_today),max(number_today)+1,1) number_today_bill, DATE_FORMAT(now(), '%d%m%y') dat_bill from bill WHERE registered=curdate()},
      onerow=>1,
    );

    my ($number_today_bill,$dat_bill)=($item->{number_today_bill}, $item->{dat_bill});
    return ($number_today_bill,qq{$company_role}.'-'.sprintf("%03d",$number_today_bill).'/'.$dat_bill);
  },
  dogovor_number_rule=>sub{
    my $f=shift; #my $dogovor_id=shift;
    my $company_role=($form->{old_values}->{company_role}==2)?'З':'П';
    my $item=$form->{db}->query(
        query=>q{SELECT if(max(number_today),max(number_today)+1,1) number_today, DATE_FORMAT(now(), '%d%m%y') dat from dogovor WHERE registered=curdate()},
        onerow=>1
    );
    #print Dumper($item);
    my ($number_today,$dat)=($item->{number_today},$item->{dat});
    my $dogovor_number=qq{$company_role}.'-'.sprintf("%03d",$number_today).'/'.$dat;

    print "number: $dogovor_number\n";
    return ($dogovor_number,$number_today);
  },

},
