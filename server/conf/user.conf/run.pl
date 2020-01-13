
find_doubles=>sub{
  my @where=(); my @values=();
  if(my $phone=param('phone')){
    push @where,qq{c.phone=?}; push @values,$phone;
  }
  if(my $email=param('email')){
    push @where,qq{c.email=?}; push @values,$email;
  }
  my $out='';
  if(scalar(@where) && scalar(@where)==scalar(@values)){
    my $query="SELECT u.id, u.firm, m.name FROM user u JOIN user_contact c ON (c.user_id = u.id) LEFT JOIN manager m ON (u.manager_id = m.id) WHERE ".join('AND',@where);
    #pre($query);
    my $sth=$form->{dbh}->prepare($query);
    $sth->execute(@values);
    
    if($sth->rows()){
      $out.=q{<p><b>найдены дубли</b></p>}
    }
    while(my $item=$sth->fetchrow_hashref()){
      $out.=qq{<a href="./edit_form.pl?config=user&action=edit&id=$item->{id}" targer="_blank">$item->{firm}</a> ($item->{name})<br>}
    }
  }
  if($out){
    print $out;
  }
  else{
    print 'дубли не найдены'
  }
  
},
cur_date=>sub{ 
    my $x=shift;
    my ($mday,$mon,$year);
    if($x=~m/^\d+$/){
            ($mday,$mon,$year)=(localtime(time-86400*$x))[3,4,5];
    }
    else{
            ($mday,$mon,$year)=(localtime(time))[3,4,5];
    }
    return sprintf ("%4d-%02d-%02d",$year+1900,$mon+1,$mday);
},

date_to_int=>sub{
  my $d=shift;
  $d=~s/\s+.+$//;
  $d=~s/[^\d]//gs;
  return $d;
},
refresh_bill=>sub{ # перевыставить счёт
        my $bill_id=shift;
      
        my $company_role=($form->{old_values}->{company_role}==2)?'З':'П';
        
        #$form->{dbh}->{AutoCommit}=0;
        
        $form->{dbh}->begin_work;
        #print "1";
        
        my $sth=$form->{dbh}->prepare(q{
          SELECT
            if(max(number_today),max(number_today)+1,1), DATE_FORMAT(now(), '%e%m%y')
          FROM
            bill
          WHERE registered=curdate()
        });
        $sth->execute();
        my ($number_today,$dat)=$sth->fetchrow();
        my $number=qq{$company_role}.'-'.sprintf("%03d",$number_today).'/'.$dat;
        $sth=$form->{dbh}->prepare("UPDATE bill SET registered=curdate(),number_today=?,number=? WHERE id=$bill_id");
        $sth->execute($number_today,$number);
        $form->{dbh}->commit;
        $form->{dbh}->{AutoCommit}=1;
        if($form->{id}){
          print qq{Счёт успешно перевыставлен. Новый номер: $number <a href="./edit_form.pl?config=user&action=edit&id=$form->{id}">в карту</a>};
        }
},
paid_doc_pack=>sub{ # помечаем счёт как оплаченный
      my $id=shift;
       if($id=~m/^\d+$/){
         my $sth=$form->{dbh}->prepare(q{
           SELECT 
             from_days(to_days(now())+t.count_days) paid_to
           FROM 
             docpack dp 
             LEFT JOIN tarif t ON (dp.tarif_id = t.id)
             where dp.id = ?
         });
         $sth->execute($id);
         my $paid_to=$sth->fetchrow();
        
        $sth=$form->{dbh}->prepare("UPDATE docpack set paid_date=now(),paid_to=? where id = ?");
        $sth->execute($paid_to,$id);
        
      
         if($form->{id}){
           $form->{self}->print(qq{Пакет документов успешно отмечен как оплаченный. <a href="./edit_form.pl?config=user&action=edit&id=$form->{id}">Вернуться в карту</a>});
         }
        
       }
},
gen_dogovor=>sub{ # создание договора
    my $doc_pack_id=shift;
    my $company_role=($form->{old_values}->{company_role}==2)?'З':'П';
    $form->{dbh}->begin_work;
    
    my $sth=$form->{dbh}->prepare(q{SELECT if(max(number_today),max(number_today)+1,1), DATE_FORMAT(now(), '%d%m%y') from dogovor WHERE registered=curdate()});
    $sth->execute();
    my ($number_today_dog,$dat_dog)=$sth->fetchrow();
    
    my $number_dog=qq{$company_role}.'-'.sprintf("%03d",$number_today_dog).'/'.$dat_dog;
    my $sth=$form->{dbh}->prepare('INSERT INTO dogovor(docpack_id,registered,number_today,number) values(?,curdate(),?,?)');
    $sth->execute($doc_pack_id,$number_today_dog,$number_dog) || die $form->{dbh}->errorstr;
    
    $form->{dbh}->commit;
    $form->{dbh}->{AutoCommit}=1;
  
},
gen_bill=>sub{ # создание счёта
    my $doc_pack_id=shift;
    my $company_role=($form->{old_values}->{company_role}==2)?'З':'П';
    $form->{dbh}->begin_work;
    
    my $sth=$form->{dbh}->prepare(q{SELECT if(max(number_today),max(number_today)+1,1), DATE_FORMAT(now(), '%d%m%y') from bill WHERE registered=curdate()});
    $sth->execute();
    my ($number_today_bill,$dat_bill)=$sth->fetchrow();
    my $number_bill=qq{$company_role}.'-'.sprintf("%03d",$number_today_bill).'/'.$dat_bill;
    my $summ=param('summ');
    my $comment=param('comment').'';
    
    $summ=0 unless($summ=~m{^\d+$});
    $sth=$form->{dbh}->prepare(q{
      INSERT INTO
        bill(
          docpack_id,registered,number_today,number,manager_id,group_id,
          summ,comment
        )
        
        values(?,curdate(),?,?,?,?,?,?)
    });
    $sth->execute(
      $doc_pack_id,$number_today_bill,$number_bill,
      $form->{manager}->{id},$form->{manager}->{group_id},
      $summ,$comment
    );
    my $bill_id=$sth->{mysql_insertid};
    $form->{dbh}->commit;
    $form->{dbh}->{AutoCommit}=1;
    if(param('get_bill_section')){
      my $sth=$form->{dbh}->prepare("SELECT * from bill where id=?");
      $sth->execute($bill_id);
      my $b=$sth->fetchrow_hashref;

      
        $form->{self}->template({
          template=>'./conf/user.conf/bill_section.tmpl',
          vars=>{
            b=>$b,
            form=>$form
          }
        });
      #exit;
    }
    else{
      print qq{
        Новый счёт выставлен №$number_bill.
        <a href="./edit_form.pl?config=user&action=edit&id=$form->{id}">Вернуться в карту</a>
      };
    }
    #return $number_bill;
},
delete_bill=>sub{ # Удаление счёта
    $s->print_header();
    my $bill_id=param('bill_id');
    my $error='';
    if($bill_id=~m{^\d+$}){
        my $sth=$form->{dbh}->prepare("SELECT * from bill where id=?");
        $sth->execute($bill_id);
        my $bill=$sth->fetchrow_hashref;
        
        
        
        if($form->{manager}->{login} ne 'admin' && !$form->{manager}->{permissions}->{admin_paids}){ # если не администратор платежей
          if($bill->{paid}){
            
            $error='Оплаченные счета нельзя удалять!';
          }
          elsif(
            $bill->{group_id}!~$form->{manager}->{CHILD_GROUPS} &&
            $bill->{manager_id}!=$form->{manager}->{id}
          ){
            
            $error='Вам нельзя удалить этот счёт'
          }
          else{
            
            $form->{dbh}->do(qq{DELETE FROM bill where id=$bill_id});
            $s->print(1);
          }
          
        }
        else{
          $form->{dbh}->do(qq{DELETE FROM bill where id=$bill_id});
          $s->print(1);
        }
    }
    else{
      $s->print('Не указан bill_id')->end;
    }
    $s->print($error)->end;
    return;
},


out_docpack_info=>sub{
    # вывод информации для пакета документов: договор, счета
    
    my $docpack_id=shift;
    if($docpack_id){
      my $doc_link="/tools/load_document.pl?doc_pack_id=$docpack_id";
      $form->{dbh}->do("SET lc_time_names = 'ru_RU'");
      my $sth=$form->{dbh}->prepare(q{
        SELECT 
          dp.*,
          DATE_FORMAT(d.registered, '%e %M %Y') d_from,
          d.number d_number,
          t.summ tarif_summ,concat(docpack_id,'_',number_today) dog_ind
        FROM docpack dp
        LEFT JOIN dogovor d ON (d.docpack_id=dp.id)
        LEFT JOIN tarif t ON (t.id=dp.tarif_id)
        where dp.id = ?
        ORDER BY dp.id desc
      });
      $sth->execute($docpack_id);
      my $docpack=$sth->fetchrow_hashref();
      
     
      my $sth=$form->{dbh}->prepare("SELECT * from bill where docpack_id=? order by paid_date desc, id desc");
      $sth->execute($docpack_id);
      my $bill_list=$sth->fetchall_arrayref({});
      #return 'ZZZ';
      return
        $form->{self}->template({
          template=>'./conf/user.conf/docpack_section.tmpl',
          vars=>{
            bill_list=>$bill_list,
            docpack=>$docpack,
            doc_link=>$doc_link,
            docpack_id=>$docpack_id,
            #form=>$form
          }
        });
    }
},
update_bill_comment=>sub{ # обновление комментария у счёта
  $s->print_header();
  my $bill_id=param('bill_id');
  
  if($bill_id=~m{^\d+$}){
    # проверяем, можно ли менять комментарий
    my $sth=$form->{dbh}->prepare(q{
      SELECT
        b.*, m.group_id
      FROM
        user wt
        JOIN docpack dp ON wt.id=dp.user_id
        JOIN bill b ON b.docpack_id=dp.id
        LEFT JOIN manager m ON m.id=b.manager_id
      WHERE wt.id=? and b.id=?
    });
    $sth->execute($form->{id},$bill_id);
    my $bill=$sth->fetchrow_hashref;
    if(
      !$form->{manager}->{permissions}->{admin_paids}
        &&
      (
        $bill->{paid}
          ||
        ($bill->{group_id}!~$form->{manager}->{CHILD_GROUPS})
          ||
        ($bill->{manager_id}!=$form->{manager}->{id})
        
      )
    ){
      print "запрещено изменять комментарий";
    }
    else{
      print '1';
      my $comment=param('comment');
      $comment=~s{^\s+}{}g; $comment=~s{\s+$}{}g;
      my $sth=$form->{dbh}->prepare("UPDATE bill set comment=? where id=?");
      $sth->execute($comment,$bill_id);
      
    }
  }
  
  exit;
  
}
