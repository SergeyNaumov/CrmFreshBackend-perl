

# {
#   #description=>'Посмотреть все счета',
#   name=>'bill_search',
#   type=>'code',
#   code=>sub{
#     #return '' unless($form->{id});

#     return qq{
#     <a target="_blank" href="/find_objects.pl?config=bill&f_user_id=$form->{id}&order_f_user_id=10&order_number=11&order_summ=12&order_comment=13&order_registered=14&registered_low=2018-01-22&registered_hi=2018-01-22&filter_registered_disabled=1&order_paid_date=15&paid_date_low=2018-01-22&paid_date_hi=2018-01-22&filter_paid_date_disabled=1&order_paid_to=16&paid_to_low=2018-01-22&paid_to_hi=2018-01-22&filter_paid_to_disabled=1&order_group_id=17&order_manager_id=18">
#       Посмотреть все счета
#     </a>};
#   },
#   tab=>'docpack',
# },
{
  description=>'Пакеты документов',
  type=>'docpack',
  name=>'docpack',
  tab=>'docpack',
},
# {
#   #description=>'Пакеты документов',
#   type=>'1_to_m',
#   name=>'docpack',
#   tab=>'docpack',
#   table=>'docpack',
#   table_id=>'id',
#   make_delete=>0,
#   full_str=>1,
#   order=>'id desc',
#   before_code=>sub{
#     my $e=shift;
#     $e->{make_delete}=1 if($form->{is_admin} || $form->{manager}->{permissions}->{admin_paids});

#     #if($form->{action} eq 'add_form'){
#       #unshift @{$e->{fields}},{
#         #name=>'not_create_bill',
#         #description=>'Не создавать счёт',
#         #type=>'checkbox'
#       #};
#     #}
    
#   },
#   full_str=>1,
#   foreign_key=>'user_id',
#   fields=>[
#     {

#         description=>'Тариф',
#         name=>'tarif_id',
#         regexp=>'^\d+$',
#         type=>'select_from_table',
#         table=>'tarif',
#         where=>'enabled=1 and blank_bill_id is not null and blank_bill_id<>0 and blank_dogovor_id is not null and blank_dogovor_id<>0',
#         header_field=>'header',
#         value_field=>'id',
        
#     },
#     {
#       description=>'Юр.Лицо',
#       name=>'ur_lico_id',
#       type=>'select_from_table',
#       table=>'ur_lico',
#       header_field=>'firm',
#       value_field=>'id',
#       regexp=>'^\d+$',

      
#       before_code=>sub{
#         my $e=shift;
#         if($form->{action}=~m{add_form}){
#           $e->{sql}=qq{
#             select
#               u.id,u.firm header 
#             from
#               ur_lico u
#               left join ur_lico_access_only a ON (a.ur_lico_id=u.id and a.manager_id=$form->{manager}->{id})
#             WHERE u.for_all=1 or a.id is not null
#           };
#         }
#         #where=>'for_all=1',
#       }
#     },
#     {
#       description=>'Момент создания',
#       type=>'datetime',
#       name=>'registered',
#       default_value=>'func::now()',
#         before_code=>sub{
#           my $e=shift;
#           $e->{read_only}=1 if( ($form->{script} eq 'load_1_to_m.pl' && $form->{action} eq 'add_form') || ($form->{script} eq 'edit_form.pl' && $form->{action} eq 'new'));
#         }
#     },
#     {
#       description=>'Создал',
#       type=>'select_from_table',
#       table=>'manager',
#       header_field=>'name',
#       value_field=>'id',
#       name=>'manager_id',
#       read_only=>1,
#       before_code=>sub{
#         my $e=shift;
#         #pre($form->{manager});
#         if($form->{action} eq 'add' || $form->{action} eq 'insert'){
#           #pre $form->{manager};
#           $e->{value}=$form->{manager}->{id};
#           $e->{read_only}=0;
#           #pre($e);
#           #exit;
#         }
#       }
#     },
#     {
#       description=>'Информация',
#       name=>'info',
#       type=>'code',
#       full_str_slide=>1,
#       not_description_in_slide=>1,
#       code=>sub{
#         my $e=shift;
#         if($e->{id}){
          
#           my $doc_link="/tools/load_document.pl?doc_pack_id=$e->{id}";
#           my $out=qq{
#           <table>
#             <tr><td>договор:</td><td><a href="$doc_link&format=doc&type=dogovor">doc</a> | <a href="$doc_link&format=pdf&type=dogovor">pdf</a></td></tr>
#             <tr><td>счёт:</td><td><a href="$doc_link&format=doc&type=bill">doc</a> | <a href="$doc_link&format=pdf&type=bill">pdf</a></td></tr>
#           </table>};
#           my $sth=$form->{dbh}->prepare("SELECT * from docpack d where id = ?");
#           $sth->execute($e->{id});
#           my $old_values=$sth->fetchrow_hashref();
#           if($old_values->{paid_date}=~m/[1-9]/){
#             $out.=qq{
#               <hr>
#               дата оплаты: $old_values->{paid_date}<br>
#               оплачено до: $old_values->{paid_to}
#             };
#           }
          
#           elsif($form->{manager}->{login} eq 'admin'){

            
#               $out.=qq{<hr><a href="./edit_form.pl?config=user&doc_pack_id=$e->{id}&action=paid_doc_pack" target="_blank">Оплатить</a>}
            
#           }
            
#           return $out;
#         }
#         return '-';
#       },
     
#       slide_code=>sub{
#         #pre(\@_);
#         my $e=$_[1] ;
#         &{$form->{run}->{out_docpack_info}}($e->{id});
#       }
#     },

#   ],
#   after_insert_code=>sub{
#     my $e=shift;
#     my $doc_pack_id=$e->{id};
#     &{$form->{run}->{gen_dogovor}}($doc_pack_id);

#     # счёт
#     #unless($not_create_bill){
#     #  &{$form->{run}->{gen_bill}}($doc_pack_id);
#     #}
#   },
#   code=>sub{
#     my $e=shift;
#     if($form->{action} eq 'new'){
#       return 'данное поле доступно после сохрания карты'
#     }
#     return $e->{field};
    
#   },
#   view_type=>'list',
# },
