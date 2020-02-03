package CRM::Docpack;
use utf8;
use strict;
use Data::Dumper;

sub process{
    
    my %arg=@_;

    

    my $form=CRM::read_conf(%arg);
    
    my ($s,$R,$name)=($arg{'s'},$arg{R}, $arg{name});

    my $action;
    if(!$R || ref($R) ne 'HASH'){
        push @{$form->{errors}},'отсутствуют параметры'
    }
    else{
        $action=$R->{action};
    }
    
    if($form->{id}!~m/^\d+$/){
        push @{$form->{errors}},'отсутствует параметр id'
    }
    elsif(!$action){
        push @{$form->{errors}},'отсутствует параметр action'
    }
    
    if(scalar(@{$form->{errors}})){
        print_response($s,$form);
        return
    }
    


    my $field=$form->{fields_hash}->{$name};

    if($action eq 'list'){
        # пакеты документов
        my $list=$form->{db}->query(
            query=>q{
                select
                    dp.id, dp.ur_lico_id, dp.tarif_id, t.header tarif, ul.firm ur_lico, dp.registered, m.name manager,
                    if(ul.for_all or a.id is not null,1,0) make_new_bill
                    
                from
                    docpack dp
                    LEFT join tarif t ON dp.tarif_id=t.id
                    LEFT join ur_lico ul ON (dp.ur_lico_id=ul.id)
                    LEFT JOIN ur_lico_access_only a ON (a.ur_lico_id=ul.id and a.manager_id=?) 
                    LEFT JOIN manager m ON (m.id=dp.manager_id)
                    
                WHERE
                    dp.user_id=? 
                ORDER BY dp.id desc
                
            },
            values=>[$form->{manager}->{id},$form->{id}]
        );

        # подтягиваем список договоров для каждого пакета документов
        my @id_list=map {$_->{id}} @{$list};
        if(scalar(@id_list)){
            my $dogovor_list=$form->{db}->query(
                query=>'SELECT * from dogovor where docpack_id in ('.join(',',@id_list).') ORDER by registered desc',
                #debug=>1
            );
            #print Dumper($dogovor_list);

            #$form->{manager}->{permissions}->{admin_paids}=0;

            foreach my $dp (@{$list}){
                $dp->{cnt_bill}=$form->{db}->query(query=>'select count(*) from bill where docpack_id=?',values=>[$dp->{id}],onevalue=>1);
                if(($form->{manager}->{login} eq 'admin' || $form->{manager}->{permissions}->{admin_paids}) || !$dp->{not_add_bills}){
                    $dp->{make_new_bill}=1;
                }

                $dp->{dogovor_list}=[];
                foreach my $d (@{$dogovor_list}){
                    $d->{show}=0;
                    if($dp->{id}==$d->{docpack_id}){
                        #print "$dp->{id}==$d->{docpack_id}\n";
                        push @{$dp->{dogovor_list}},$d;
                    }
                }
            }
        }

        print_response($s,$form,permissions=>$form->{manager}->{permissions},list=>$list);
        return ;
    }
    elsif($action eq 'get_bills'){
        my $list=get_bills($s,$form,$R);
        print_response($s,$form,list=>$list); 

    }
    elsif($action eq 'create_bill'){
        my $list=[];
        my $summ=$R->{summ};

        my $comment=$R->{comment};
        if($summ!~m/^\d+(\.\d+)?$/){
            push @{$form->{errors}},'сумма не указана или указана не верно'
        }
        elsif($R->{dogovor_id}!~m/^\d+$/){
            push @{$form->{errors}},'отсутствует параметр dogovor_id';
        }
        else{
            
            $form->{db}->{connect}->begin_work;

            my ($number_today,$number_bill)=&{$field->{bill_number_rule}}($field,$R->{dogovor_id});
            #print "$number_today,$number_bill\n";
            $comment='' unless($comment);
            #print Dumper({save=>$form->{db}});
            $form->{db}->save(
                table=>'bill',
                data=>{
                    docpack_id=>$R->{dogovor_id},
                    registered=>'func::curdate()',
                    number_today=>$number_today,
                    number=>$number_bill,
                    manager_id=>$form->{manager}->{id},
                    group_id=>$form->{manager}->{group_id},
                    summ=>$summ,
                    comment=>$comment
                },
            );
            my $list=get_bills($s,$form,$R);
            $form->{db}->{connect}->commit;
            $form->{db}->{connect}->{AutoCommit}=1;
        }
        print_response($s,$form,list=>$list); 
    }
    elsif($action eq 'init_new_docpack_form'){ # списки, необходимые для создания нового пакета документов
        my $need_manager_field=need_manager_field(form=>$form);
        print_response($s,$form,
            ur_lico_list=>$form->{db}->query(query=>'select id v,firm d from ur_lico  order by firm'),
            tarif_list=>$form->{db}->query(query=>'select id v,header d from tarif where enabled=1 order by header'),
            # для админа и 
            need_manager_field=>$need_manager_field,
            manager_list=>$need_manager_field?$form->{db}->query(query=>'select id v,name d from manager where enabled=1 order by name'):[],
            cur_manager_id=>$form->{manager}->{id}
        );
    }
    elsif($action eq 'create_docpack'){ # Создание пакета документов
        my $need_manager_field=need_manager_field(form=>$form);
        my $manager_id=$form->{manager}->{id};
        if($need_manager_field && $R->{manager_id}=~m/^\d+$/){
            $manager_id=$R->{manager_id}
        }
        #my %arg=();
        if(!scalar(@{$form->{errors}})){
            $form->{db}->{connect}->begin_work;
            my ($number,$number_today);
            eval {
                
                ($number,$number_today)=&{$field->{dogovor_number_rule}}($field);

            };
            if($@){
                push @{$form->{errors}},'error in dogovor_number_rule: '.$@;
            }
            else{
                my $docpack_id=$form->{db}->save(
                    table=>'docpack',
                    data=>{
                        user_id=>$form->{id},
                        tarif_id=>$R->{tarif_id},
                        ur_lico_id=>$R->{ur_lico_id},
                        manager_id=>$manager_id,
                        registered=>'func::now()'
                    },
                );

                $form->{db}->save(
                    table=>'dogovor',
                    data=>{
                        docpack_id=>$docpack_id,
                        registered=>'func::curdate()',
                        number_today=>$number_today,
                        number=>$number
                    },
                );
            }

            $form->{db}->{connect}->commit;
            $form->{db}->{connect}->{AutoCommit}=1;

        }
        print_response($s,$form);
    }
    elsif($action eq 'docpack_delete'){
        if($R->{docpack_id}=~m/^\d+$/){
            my $count_bill=$form->{db}->query(
                query=>'SELECT count(*) from bill where docpack_id=?',
                values=>[$R->{docpack_id}],
                onevalue=>1
            );
            if($count_bill){
                push @{$form->{errors}},'данный пакет документов содержит счета'
            }
            else{
                $form->{db}->query(
                    query=>'DELETE FROM docpack where id=?',
                    values=>[$R->{docpack_id}]
                );
            }
        }
        print_response($s,$form);
    }
}
sub need_manager_field{
    my %arg=@_; my $form=$arg{form};
    return ($form->{manager}->{login} eq 'admin' || $form->{manager}->{permissions}->{admin_paids})
}
sub get_bills{ # список счетов
    my ($s,$form,$R)=@_;
    my $list=[];
    if($R->{dogovor_id}=~m/^\d+$/){
        $list=$form->{db}->query(
            query=>q{
                SELECT
                    b.*
                from
                    docpack dp
                    JOIN bill b ON b.docpack_id=dp.id
                where
                    dp.user_id=? and b.docpack_id=?
                order by b.id desc
            },
            values=>[$form->{id},$R->{dogovor_id}]
        );
        
    }
    else{
        push @{$form->{errors}},'отсутствует параметр dogovor_id';
        
    }
    return $list;
}
sub print_response{
    my $s=shift; my $form=shift; my %arg=@_;
    my $response={
        success=>scalar(@{$form->{errors}})?0:1,
        errors=>$form->{errors}
    };
    foreach my $k (keys(%arg)){
        $response->{$k}=$arg{$k}
    }
    $s->print_json($response)->end;
}

return 1;