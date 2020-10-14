{
    range=>sub{
        my %arg=@_;
        my $min=$arg{from};
        my $max=$arg{to};
        my $order=$arg{order};
        $order=0 unless($order);
        my $result=$min+rand($max-$min);

        my $delta=(1 / (10**$order));
        if($order){
            $result=~s/^(-?\d+\.\d{$order})\d*/$1/;
        }
        else{
            $result=~s/\.\d+//;
        }

        if(rand()>0.5){
            $result+=$delta;
        }
        else{
            $result-=$delta;
        }
        return $result
    },
    get_values_form_modifications=>sub{
      my $v=shift;
      my $modification_values=$s->to_json($form->{db}->query(query=>'select id as v, header as d from reestr_si_modification WHERE reestr_si_id=?',values=>[$v]));
      return ['reestr_si_modification_id',{values=>$modification_values}];
    },
    ajax_dat_pov_next=>sub{
        my $s=shift; my $v=shift;
        my $result_num_sv=$form->{run}->{ajax_num_sv}($s,$v);

        my $result=[];

        #print "grsi_num: $v->{grsi_num} ; dat_pov: $v->{dat_pov} ; type_wather: $v->{type_wather}\n";
        if($v->{grsi_num} && $v->{grsi_num}=~m/^\d+$/ && $v->{dat_pov}=~m/[1-9]/ && $v->{type_wather}){
            my $reestr=$s->{db}->query(
                query=>'select * from reestr_si where id=?',
                values=>[$v->{grsi_num}],
                onerow=>1
            );

            my $modification_values=$form->{run}->{get_values_form_modifications}($v->{grsi_num});
            
            if($reestr){

                my $delta=($v->{type_wather} eq 'gv')?$reestr->{pov_g}:$reestr->{pov_h};
                if($v->{is_ok}){
                    if($v->{dat_pov}=~m/^(\d{4})-(\d{2})-(\d{2})$/){
                        
                            my ($y,$m,$d)=($1,$2,$3);
                            $y+=$delta;

                            ($d,$m,$y)=(localtime(str2time("$y-$m-$d")-86400))[3,4,5];
                            #print "($y,$m,$d)\n";
                            $result=[
                                'dat_pov_next',{value=>sprintf("%04d-%02d-%02d",$y+1900,$m+1,$d)},
                                @{$modification_values}
                            ];
                            
                    }
                    else{

                        $result=[
                            'dat_pov',{error=>"какая-то странная у Вас дата"},
                            @{$modification_values}
                        ]
                    }
                }
                else{
                    $result=[
                        'dat_pov_next',{value=>''},
                        @{$modification_values}
                    ]
                }
            }
            else{
                $result=[
                    'grsi_num',{error=>"Номер $v->{grsi_num} не найден в реестре СИ"},
                    #'reestr_si_modification_id',{values=>$modification_values}
                ]
            }
        }
        elsif($v->{grsi_num}){ # если ничего не указано, но номер ГРСИ всё-таки выбран -- выводим модификации
            my $r_modification_values=$form->{run}->{get_values_form_modifications}($v->{grsi_num});
            $result=[@{$r_modification_values}]
        }
        if(scalar(@{$result_num_sv})){
            push @{$result},@{$result_num_sv};
        }

        
        return $result;
    },
    ajax_num_sv=>sub{
        my $s=shift; my $v=shift;
        my $ov=$form->{ov};
        my $not_calc_num_label=0;
        if($form->{id}){
            if( ($v->{num_sv1} eq $ov->{num_sv1}) && ($v->{dat_pov} eq $ov->{dat_pov}) && ($v->{main_master_id}==$ov->{main_master_id})){
                $not_calc_num_label=1;
            }
        }

        my $modification_values=$form->{run}->{get_values_form_modifications}($v->{grsi_num});


        my $result=[@{$modification_values}];

        my $main_master;
        if($form->{id} && $v->{main_master_id}==$ov->{main_master_id}){
            $main_master={id=>$v->{main_master_id}}
        }
        else{
            $main_master=$form->{db}->query(
                query=>'SELECT id from main_master where tnumber=?',
                values=>[$v->{num_sv2}], onerow=>1
            );

            if($main_master && $v->{main_master_id} ne $main_master->{id}){
                push @{$result},(
                    'main_master_id',{value=>$main_master->{id},error=>''}
                );
            }
        }


        my ($Y,$M,$D);
        if($form->{id} && $ov->{dat_pov} eq $v->{dat_pov}){
            # не передаём на вывод dat_pov
        }
        else{
            if($v->{dat_pov}=~m/^(\d{4})-(\d{2})-(\d{2})$/){
                push @{$result},('dat_pov',{error=>''});
                $Y=$1; $M=$2; $D=$3;
            }
            else{
                push @{$result},('dat_pov',{error=>'заполните дату поверки'});
                return $result;
            }
        }

        if($main_master){
            #if($master->{main_master_id}){
            #  push @{$result},('main_master_id',{value=>$master->{main_master_id}} );
            #}
            #push @{$result},('num_label',{error=>''});
            #print Dumper({resule=>$result});
            #if(!$v->{num_sv1}){
            if($v->{num_sv2} && $v->{dat_pov}=~m/[1-9]/){

                my $where='num_sv2=? and dat_pov=?';
                if($form->{id}){
                  $where.=" and id<>$form->{id}"
                }

                if(!$not_calc_num_label){
                    my $num_sv1=$form->{db}->query(
                      query=>'SELECT max(num_sv1) from work WHERE '.$where,
                      values=>[$v->{num_sv2},$v->{dat_pov}],
                      onevalue=>1,
                    );
                    
                    $num_sv1++;
                    
                    if($num_sv1 ne $v->{num_sv1}){
                      $v->{num_sv1}=$num_sv1;
                      my $warning='';
                      push @{$result},('num_sv1',{value=>$num_sv1,error=>'',warning=>$warning});
                    }
                }
                
            }
            if(!$not_calc_num_label){
                push @{$result},(
                    'num_label',{
                        value=>"$v->{dat_pov}/$v->{num_sv2}/$v->{num_sv1}",
                        error=>'',
                    }
                );

                push @{$result},(
                  'num_sv2',{error=>''}
                );
            }



        }
        else{
            $result=[
              'num_sv2',
              {
                error=>'табельный номер не найден'
              },
              'num_label',{value=>'', error=>'не получится вычислить, поскольку не найден табельный номер'}
            ]

        }

        return $result
    },
}