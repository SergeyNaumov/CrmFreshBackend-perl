package CRM::LoadDocument;
# Этот модуль должен быть без флага utf8
use strict;
use Data::Dumper;
use odt_file2;
use Lingua::RU::Number qw(rur_in_words);
our @EXPORT_OK = qw/print_error  print_header print_template html_strip send_mes encodeJSON next_date pre cur_time cur_date/;
# хак для Data::Dumper + utf8
$Data::Dumper::Useqq = 1;
$Data::Dumper::Useperl = 1;
{ no warnings 'redefine';
    sub Data::Dumper::qquote {
        my $s = shift;
        return "'$s'";
    }
}
# хак для Data::Dumper + utf8

my $user_table='user'; 
my $docpack_foreign_key='user_id'; 
my ($db,$s,$const,$env,$errors);
sub process{
    $s=shift; my $request_filename=shift; $db=$s->{db_r}; $env=$s->{vars}->{env}; $errors=[];
    if(exists $s->{config}->{docpack}){
      $user_table=$s->{config}->{docpack}->{user_table} if($s->{config}->{docpack}->{user_table});
      $docpack_foreign_key=$s->{config}->{docpack}->{docpack_foreign_key} if($s->{config}->{docpack}->{docpack_foreign_key});
    }
    print Dumper({user_table=>$user_table});
    my $filename_prefix;
    if($s->{config}->{use_project}){
      $const={
        template_path=>"./files/project_$s->{project}->{id}/blank_document",
        template=>'',
      };
    }
    else{
      $const={
        template_path=>'./files/blank_document',
        template=>'',
      };      
    }

    
    my $format=$s->param('format'); 
    my $id=$s->param('doc_pack_id'); my $type=$s->param('type');


    $db->query(query=>q{SET lc_time_names = 'ru_RU'});
    my $data;
    my $bill_id=$s->param('bill_id');
    my $act_id=$s->param('act_id');
    if($type=~m{^(bill|paid)$} && $bill_id=~m{^\d+$}){
      if($s->{config}->{use_project}){
      $data=
            $db->query(query=>q{
              SELECT
                u.inn, u.firm, u.kpp, u.address, u.ur_address,
                m.name manager_name,
                t.header tarif_name,
                t.cnt_orders tarif_cnt_orders,
                bill.summ tarif_summ, bill.summ bill_summ, round((bill.summ/  if(YEAR(bill.registered)<2019,1.18,1.20)  ),2) bill_summ_without_nds,
                round(bill.summ - (bill.summ/  if(YEAR(bill.registered)<2019,1.18,1.20)  ),2) bill_summ_nds,
                t.count_days tarif_count_days, t.percent_pob, t.comment tarif_comment,
                b_dog.attach dogovor_blank,
                b_bill.attach bill_blank,
                dp.registered dp_registered, dp.id dp_id, dp.tarif_id,
                ur_lico.firm ur_lico_firm, ur_lico.warn_for_bill ur_lico_warn_for_bill, ur_lico.gen_dir_fio_im ur_lico_gen_dir_fio_im, ur_lico.gen_dir_fio_rod ur_lico_gen_dir_fio_rod,
                ur_lico.buh_fio_im ur_lico_buh_fio_im, ur_lico.buh_fio_rod ur_lico_buh_fio_rod, ur_lico.inn ur_lico_inn, ur_lico.ogrn ur_lico_ogrn,
                ur_lico.kpp ur_lico_kpp, ur_lico.rs ur_lico_rs, ur_lico.ks ur_lico_ks, ur_lico.bik ur_lico_bik, ur_lico.bank ur_lico_bank,
                ur_lico.attach ur_lico_attach, ur_lico.ur_address ur_lico_ur_address, ur_lico.address ur_lico_address,
                ur_lico.attach_pechat ur_lico_attach_pechat,ur_lico.gendir_podp ur_lico_gendir_podp, ur_lico.buh_podp ur_lico_buh_podp,
                ur_lico.gen_dir_f_in ur_lico_gen_dir_f_in, dogovor.number dogovor_number, bill.number bill_number,
                DATE_FORMAT(dogovor.registered, '%e %M %Y') dogovor_from, DATE_FORMAT(bill.registered, '%e %M %Y') bill_from,
                bill.payment_order, bill.registered bill_registered, bill.service_name bill_service_name
              FROM
                project_client u 
                LEFT JOIN project_manager m ON (u.manager_id =m.id)
                JOIN docpack dp ON dp.client_id = u.id
                LEFT JOIN dogovor  ON (dp.id=dogovor.docpack_id)
                LEFT JOIN bill ON (dp.id=bill.docpack_id)
                
                LEFT JOIN tarif t ON (t.id = dp.tarif_id)
                LEFT JOIN blank_document b_dog ON (b_dog.id = t.blank_dogovor_id)
                LEFT JOIN blank_document b_bill ON (b_bill.id = t.blank_bill_id)
                LEFT JOIN ur_lico ON (ur_lico.id=dp.ur_lico_id)
              WHERE dp.id = ? and dp.project_id=?  and bill.id=?
            },
            errors=>$errors,
            values=>[$id,$s->{project}->{id}, $bill_id],onerow=>1);
      }
      else{
        $data=
            $db->query(query=>qq{
              SELECT
                if(requis.inn is not null, requis.inn,u.inn) inn, 
                if(requis.firm is not null, requis.firm,u.firm) firm,
                if(requis.kpp is not null, requis.kpp,u.kpp) kpp,
                if(requis.address is not null, requis.address,u.address) address,
                if(requis.ur_address is not null, requis.ur_address,u.ur_address) ur_address,
                m.name manager_name,
                t.header tarif_name,
                t.cnt_orders tarif_cnt_orders,
                bill.summ tarif_summ, bill.summ bill_summ, round((bill.summ/  if(YEAR(bill.registered)<2019,1.18,1.20)  ),2) bill_summ_without_nds,
                round(bill.summ - (bill.summ/  if(YEAR(bill.registered)<2019,1.18,1.20)  ),2) bill_summ_nds,
                t.count_days tarif_count_days, t.percent_pob, t.comment tarif_comment,
                b_dog.attach dogovor_blank,
                b_bill.attach bill_blank,
                dp.registered dp_registered, dp.id dp_id, dp.tarif_id,
                ur_lico.firm ur_lico_firm, ur_lico.warn_for_bill ur_lico_warn_for_bill, ur_lico.gen_dir_fio_im ur_lico_gen_dir_fio_im, ur_lico.gen_dir_fio_rod ur_lico_gen_dir_fio_rod,
                ur_lico.buh_fio_im ur_lico_buh_fio_im, ur_lico.buh_fio_rod ur_lico_buh_fio_rod, ur_lico.inn ur_lico_inn, ur_lico.ogrn ur_lico_ogrn,
                ur_lico.kpp ur_lico_kpp, ur_lico.rs ur_lico_rs, ur_lico.ks ur_lico_ks, ur_lico.bik ur_lico_bik, ur_lico.bank ur_lico_bank,
                ur_lico.attach ur_lico_attach, ur_lico.ur_address ur_lico_ur_address, ur_lico.address ur_lico_address,
                ur_lico.attach_pechat ur_lico_attach_pechat,ur_lico.gendir_podp ur_lico_gendir_podp, ur_lico.buh_podp ur_lico_buh_podp,
                ur_lico.gen_dir_f_in ur_lico_gen_dir_f_in, dogovor.number dogovor_number, bill.number bill_number,
                DATE_FORMAT(dogovor.registered, '%e %M %Y') dogovor_from, DATE_FORMAT(bill.registered, '%e %M %Y') bill_from,
                bill.payment_order, bill.registered bill_registered, bill.service_name bill_service_name
              FROM
                $user_table u 
                LEFT JOIN manager m ON (u.manager_id =m.id)
                JOIN docpack dp ON dp.$docpack_foreign_key = u.id
                LEFT JOIN dogovor  ON (dp.id=dogovor.docpack_id)
                LEFT JOIN bill ON (dp.id=bill.docpack_id)
                LEFT JOIN buhgalter_card_requisits requis ON (bill.requisits_id=requis.id)
                LEFT JOIN tarif t ON (t.id = dp.tarif_id)
                LEFT JOIN blank_document b_dog ON (b_dog.id = t.blank_dogovor_id)
                LEFT JOIN blank_document b_bill ON (b_bill.id = t.blank_bill_id)
                LEFT JOIN ur_lico ON (ur_lico.id=dp.ur_lico_id)
              WHERE dp.id = ? and bill.id=?
            },values=>[$id,$bill_id],onerow=>1);
      }

          #}.#q{JOIN buhgalter_card_requisits requis ON (bill.requisits_id=requis.id)}.
              #q{
          
          $data->{stavka_nds}='18%';
          if($data->{bill_registered}=~m{^(\d+)}){
            my $year=$1;
            if($year>2018){
              $data->{stavka_nds}='20%';
            }
          }

    }
    elsif($type=~m{^(act|fact)$} && $act_id=~m{^\d+$}){ # акт или счёт-фактура
     if($s->{config}->{use_project}){
          $data=
              $db->query(query=>q{
                SELECT
                  requis.*,
                  m.name manager_name,
                  t.header tarif_name,
                  t.cnt_orders tarif_cnt_orders,
                  bill.summ tarif_summ, bill.summ bill_summ, 
                  round( (bill.summ / if(YEAR(act.registered)<2019,1.18,1.20) ),2) bill_summ_without_nds,
                  round(bill.summ - (bill.summ/if(YEAR(act.registered)<2019,1.18,1.20) ),2) bill_summ_nds,
                  t.count_days tarif_count_days, t.percent_pob, t.comment tarif_comment,
                  b_act.attach act_blank, b_fact.attach fact_blank,
                  dp.registered dp_registered, dp.id dp_id, dp.tarif_id,
                  ur_lico.firm ur_lico_firm, ur_lico.gen_dir_fio_im ur_lico_gen_dir_fio_im, ur_lico.gen_dir_fio_rod ur_lico_gen_dir_fio_rod,
                  ur_lico.buh_fio_im ur_lico_buh_fio_im, ur_lico.buh_fio_rod ur_lico_buh_fio_rod, ur_lico.inn ur_lico_inn, ur_lico.ogrn ur_lico_ogrn,
                  ur_lico.kpp ur_lico_kpp, ur_lico.rs ur_lico_rs, ur_lico.ks ur_lico_ks, ur_lico.bik ur_lico_bik, ur_lico.bank ur_lico_bank,
                  ur_lico.attach ur_lico_attach, ur_lico.ur_address ur_lico_ur_address, ur_lico.address ur_lico_address,
                  ur_lico.attach_pechat ur_lico_attach_pechat,ur_lico.gendir_podp ur_lico_gendir_podp, ur_lico.buh_podp ur_lico_buh_podp,
                  ur_lico.gen_dir_f_in ur_lico_gen_dir_f_in, dogovor.number dogovor_number, bill.number bill_number,
                  DATE_FORMAT(dogovor.registered, '%e %M %Y') dogovor_from, DATE_FORMAT(bill.registered, '%e %M %Y') bill_from,
                  act.number act_number, act.registered act_registered,
                  act.summ act_summ, round((act.summ/ if(YEAR(act.registered)<2019,1.18,1.20) ),2) act_summ_without_nds,
                  round(act.summ - (act.summ/ if(YEAR(act.registered)<2019,1.18,1.20) ),2) act_summ_nds, bill.payment_order,bill.paid_date paid_date,
                  bill.service_name bill_service_name
                FROM
                  project_client u 
                  LEFT JOIN project_manager m ON (u.manager_id =m.id)
                  JOIN docpack dp ON dp.client_id = u.id
                  JOIN dogovor  ON (dp.id=dogovor.docpack_id)
                  JOIN bill ON (dp.id=bill.docpack_id)
                  JOIN buhgalter_card_requisits requis ON (bill.requisits_id=requis.id)
                  JOIN act ON (bill.id=act.bill_id)
                  LEFT JOIN tarif t ON (t.id = dp.tarif_id)
                  LEFT JOIN blank_document b_act ON (b_act.id = t.blank_act_id)
                  LEFT JOIN blank_document b_fact ON (b_fact.id = t.blank_billfact_id)
                  LEFT JOIN ur_lico ON (ur_lico.id=dp.ur_lico_id)
                WHERE a.project_id=? and a.act.id=?
              },values=>[$s->{project}->{id}, $act_id],onerow=>1);
      }
      else{
             $data=
              $db->query(query=>qq{
                SELECT
                  requis.*,
                  m.name manager_name,
                  t.header tarif_name,
                  t.cnt_orders tarif_cnt_orders,
                  bill.summ tarif_summ, bill.summ bill_summ, 
                  round( (bill.summ / if(YEAR(act.registered)<2019,1.18,1.20) ),2) bill_summ_without_nds,
                  round(bill.summ - (bill.summ/if(YEAR(act.registered)<2019,1.18,1.20) ),2) bill_summ_nds,
                  t.count_days tarif_count_days, t.percent_pob, t.comment tarif_comment,
                  b_act.attach act_blank, b_fact.attach fact_blank,
                  dp.registered dp_registered, dp.id dp_id, dp.tarif_id,
                  ur_lico.firm ur_lico_firm, ur_lico.gen_dir_fio_im ur_lico_gen_dir_fio_im, ur_lico.gen_dir_fio_rod ur_lico_gen_dir_fio_rod,
                  ur_lico.buh_fio_im ur_lico_buh_fio_im, ur_lico.buh_fio_rod ur_lico_buh_fio_rod, ur_lico.inn ur_lico_inn, ur_lico.ogrn ur_lico_ogrn,
                  ur_lico.kpp ur_lico_kpp, ur_lico.rs ur_lico_rs, ur_lico.ks ur_lico_ks, ur_lico.bik ur_lico_bik, ur_lico.bank ur_lico_bank,
                  ur_lico.attach ur_lico_attach, ur_lico.ur_address ur_lico_ur_address, ur_lico.address ur_lico_address,
                  ur_lico.attach_pechat ur_lico_attach_pechat,ur_lico.gendir_podp ur_lico_gendir_podp, ur_lico.buh_podp ur_lico_buh_podp,
                  ur_lico.gen_dir_f_in ur_lico_gen_dir_f_in, dogovor.number dogovor_number, bill.number bill_number,
                  DATE_FORMAT(dogovor.registered, '%e %M %Y') dogovor_from, DATE_FORMAT(bill.registered, '%e %M %Y') bill_from,
                  act.number act_number, act.registered act_registered,
                  act.summ act_summ, round((act.summ/ if(YEAR(act.registered)<2019,1.18,1.20) ),2) act_summ_without_nds,
                  round(act.summ - (act.summ/ if(YEAR(act.registered)<2019,1.18,1.20) ),2) act_summ_nds, bill.payment_order,bill.paid_date paid_date,
                  bill.service_name bill_service_name
                FROM
                  $user_table u 
                  LEFT JOIN manager m ON (u.manager_id =m.id)
                  JOIN docpack dp ON dp.$docpack_foreign_key = u.id
                  JOIN dogovor  ON (dp.id=dogovor.docpack_id)
                  JOIN bill ON (dp.id=bill.docpack_id)
                  JOIN buhgalter_card_requisits requis ON (bill.requisits_id=requis.id)
                  JOIN act ON (bill.id=act.bill_id)
                  LEFT JOIN tarif t ON (t.id = dp.tarif_id)
                  LEFT JOIN blank_document b_act ON (b_act.id = t.blank_act_id)
                  LEFT JOIN blank_document b_fact ON (b_fact.id = t.blank_billfact_id)
                  LEFT JOIN ur_lico ON (ur_lico.id=dp.ur_lico_id)
                WHERE act.id=?
              },values=>[$act_id],onerow=>1);
      }
      $data->{stavka_nds}='18%';
      if($data->{act_registered}=~m{^(\d+)}){
        my $year_act=$1;
        if($year_act>2018){
          $data->{stavka_nds}='20%';
        }
      }

      
    }
    elsif($type eq 'av_fact' && $bill_id=~m{^\d+$}){ # авансовая счёт-фактура
      if($s->{config}->{use_project}){
            $data=
                $db->query(query=>q{
                  SELECT
                    u.*,
                    m.name manager_name,
                    t.header tarif_name,
                    t.cnt_orders tarif_cnt_orders,
                    bill.summ tarif_summ, bill.summ bill_summ, round((bill.summ/1.18),2) bill_summ_without_nds,
                    round(bill.summ - (bill.summ/1.18),2) bill_summ_nds,
                    t.count_days tarif_count_days, t.percent_pob, t.comment tarif_comment,
                    b_fact.attach fact_blank,
                    dp.registered dp_registered, dp.id dp_id, dp.tarif_id,
                    ur_lico.firm ur_lico_firm,  ur_lico.warn_for_bill ur_lico_warn_for_bill, ur_lico.gen_dir_fio_im ur_lico_gen_dir_fio_im, ur_lico.gen_dir_fio_rod ur_lico_gen_dir_fio_rod,
                    ur_lico.buh_fio_im ur_lico_buh_fio_im, ur_lico.buh_fio_rod ur_lico_buh_fio_rod, ur_lico.inn ur_lico_inn, ur_lico.ogrn ur_lico_ogrn,
                    ur_lico.kpp ur_lico_kpp, ur_lico.rs ur_lico_rs, ur_lico.ks ur_lico_ks, ur_lico.bik ur_lico_bik, ur_lico.bank ur_lico_bank,
                    ur_lico.attach ur_lico_attach, ur_lico.ur_address ur_lico_ur_address, ur_lico.address ur_lico_address,
                    ur_lico.attach_pechat ur_lico_attach_pechat,ur_lico.gendir_podp ur_lico_gendir_podp, ur_lico.buh_podp ur_lico_buh_podp,
                    ur_lico.gen_dir_f_in ur_lico_gen_dir_f_in, dogovor.number dogovor_number, bill.number bill_number,
                    DATE_FORMAT(dogovor.registered, '%e %M %Y') dogovor_from, DATE_FORMAT(bill.registered, '%e %M %Y') bill_from,
                    avance_fact.number act_number, avance_fact.paid_date act_registered,bill.paid_date paid_date,
                    round((bill.summ/  if(YEAR(bill.registered)<2019,1.18,1.20)  ),2) act_summ_without_nds,
                    round(bill.summ - (bill.summ/  if(YEAR(bill.registered)<2019,1.18,1.20)  ),2) act_summ_nds, bill.summ act_summ,
                    bill.payment_order
                  FROM
                    project_client u 
                    LEFT JOIN project_manager m ON (u.manager_id =m.id)
                    JOIN docpack dp ON dp.client_id = u.id
                    JOIN dogovor  ON (dp.id=dogovor.docpack_id)
                    JOIN bill ON (dp.id=bill.docpack_id)
                    JOIN avance_fact ON (avance_fact.bill_id=bill.id)
                    LEFT JOIN tarif t ON (t.id = dp.tarif_id)
                    LEFT JOIN blank_document b_fact ON (b_fact.id = t.blank_billfact_id)
                    LEFT JOIN ur_lico ON (ur_lico.id=dp.ur_lico_id)
                  WHERE bill.project_id=? and bill.id=?
                },values=>[$s->{project}->{id}, $bill_id],onerow=>1);
      }
      else{
            $data=
                $db->query(query=>qq{
                  SELECT
                    u.*,
                    m.name manager_name,
                    t.header tarif_name,
                    t.cnt_orders tarif_cnt_orders,
                    bill.summ tarif_summ, bill.summ bill_summ, round((bill.summ/1.18),2) bill_summ_without_nds,
                    round(bill.summ - (bill.summ/1.18),2) bill_summ_nds,
                    t.count_days tarif_count_days, t.percent_pob, t.comment tarif_comment,
                    b_fact.attach fact_blank,
                    dp.registered dp_registered, dp.id dp_id, dp.tarif_id,
                    ur_lico.firm ur_lico_firm,  ur_lico.warn_for_bill ur_lico_warn_for_bill, ur_lico.gen_dir_fio_im ur_lico_gen_dir_fio_im, ur_lico.gen_dir_fio_rod ur_lico_gen_dir_fio_rod,
                    ur_lico.buh_fio_im ur_lico_buh_fio_im, ur_lico.buh_fio_rod ur_lico_buh_fio_rod, ur_lico.inn ur_lico_inn, ur_lico.ogrn ur_lico_ogrn,
                    ur_lico.kpp ur_lico_kpp, ur_lico.rs ur_lico_rs, ur_lico.ks ur_lico_ks, ur_lico.bik ur_lico_bik, ur_lico.bank ur_lico_bank,
                    ur_lico.attach ur_lico_attach, ur_lico.ur_address ur_lico_ur_address, ur_lico.address ur_lico_address,
                    ur_lico.attach_pechat ur_lico_attach_pechat,ur_lico.gendir_podp ur_lico_gendir_podp, ur_lico.buh_podp ur_lico_buh_podp,
                    ur_lico.gen_dir_f_in ur_lico_gen_dir_f_in, dogovor.number dogovor_number, bill.number bill_number,
                    DATE_FORMAT(dogovor.registered, '%e %M %Y') dogovor_from, DATE_FORMAT(bill.registered, '%e %M %Y') bill_from,
                    avance_fact.number act_number, avance_fact.paid_date act_registered,bill.paid_date paid_date,
                    round((bill.summ/  if(YEAR(bill.registered)<2019,1.18,1.20)  ),2) act_summ_without_nds,
                    round(bill.summ - (bill.summ/  if(YEAR(bill.registered)<2019,1.18,1.20)  ),2) act_summ_nds, bill.summ act_summ,
                    bill.payment_order
                  FROM
                    $user_table u 
                    LEFT JOIN manager m ON (u.manager_id =m.id)
                    JOIN docpack dp ON dp.$docpack_foreign_key = u.id
                    JOIN dogovor  ON (dp.id=dogovor.docpack_id)
                    JOIN bill ON (dp.id=bill.docpack_id)
                    JOIN avance_fact ON (avance_fact.bill_id=bill.id)
                    LEFT JOIN tarif t ON (t.id = dp.tarif_id)
                    LEFT JOIN blank_document b_fact ON (b_fact.id = t.blank_billfact_id)
                    LEFT JOIN ur_lico ON (ur_lico.id=dp.ur_lico_id)
                  WHERE bill.id=?
                },values=>[$bill_id],onerow=>1);
      }
          #pre($data);
          if($data->{bill_from}=~m/2017|2018/){
            $data->{stavka_nds}='18/118';
          }else{
            $data->{stavka_nds}='20/120';
          }
          
    }
    else{
      if($s->{config}->{use_project}){
          $data=
          $db->query(query=>q{
            SELECT
              u.*,
              m.name manager_name,
              t.header tarif_name,
              t.summ tarif_summ, t.cnt_orders tarif_cnt_orders,
              t.count_days tarif_count_days, t.percent_pob, t.comment tarif_comment,
              b_dog.attach dogovor_blank,
              dp.registered dp_registered, dp.id dp_id, dp.tarif_id,
              ur_lico.firm ur_lico_firm, ur_lico.gen_dir_fio_im ur_lico_gen_dir_fio_im, ur_lico.gen_dir_fio_rod ur_lico_gen_dir_fio_rod,
              ur_lico.buh_fio_im ur_lico_buh_fio_im, ur_lico.buh_fio_rod ur_lico_buh_fio_rod, ur_lico.inn ur_lico_inn, ur_lico.ogrn ur_lico_ogrn,
              ur_lico.kpp ur_lico_kpp, ur_lico.rs ur_lico_rs, ur_lico.ks ur_lico_ks, ur_lico.bik ur_lico_bik, ur_lico.bank ur_lico_bank,
              ur_lico.attach ur_lico_attach, ur_lico.ur_address ur_lico_ur_address, ur_lico.address ur_lico_address,
              ur_lico.attach_pechat ur_lico_attach_pechat,ur_lico.gendir_podp ur_lico_gendir_podp, ur_lico.buh_podp ur_lico_buh_podp,
              ur_lico.gen_dir_f_in ur_lico_gen_dir_f_in, dogovor.number dogovor_number, 
              DATE_FORMAT(dogovor.registered, '%e %M %Y') dogovor_from, dogovor.registered dogovor_registered, dp.ur_lico_id
            FROM
              project_client u 
              LEFT JOIN project_manager m ON (u.manager_id =m.id)
              JOIN docpack dp ON dp.client_id = u.id
              LEFT JOIN dogovor  ON (dp.id=dogovor.docpack_id)
              LEFT JOIN tarif t ON (t.id = dp.tarif_id)
              LEFT JOIN blank_document b_dog ON (b_dog.id = t.blank_dogovor_id)
              LEFT JOIN ur_lico ON (ur_lico.id=dp.ur_lico_id)
            WHERE dp.project_id=? and dp.id = ?
          },values=>[$s->{project}->{id}, $id],onerow=>1);
      }
      else{
          $data=
          $db->query(query=>qq{
            SELECT
              u.*,
              m.name manager_name,
              t.header tarif_name,
              t.summ tarif_summ, t.cnt_orders tarif_cnt_orders,
              t.count_days tarif_count_days, t.percent_pob, t.comment tarif_comment,
              b_dog.attach dogovor_blank,
              dp.registered dp_registered, dp.id dp_id, dp.tarif_id,
              ur_lico.firm ur_lico_firm, ur_lico.gen_dir_fio_im ur_lico_gen_dir_fio_im, ur_lico.gen_dir_fio_rod ur_lico_gen_dir_fio_rod,
              ur_lico.buh_fio_im ur_lico_buh_fio_im, ur_lico.buh_fio_rod ur_lico_buh_fio_rod, ur_lico.inn ur_lico_inn, ur_lico.ogrn ur_lico_ogrn,
              ur_lico.kpp ur_lico_kpp, ur_lico.rs ur_lico_rs, ur_lico.ks ur_lico_ks, ur_lico.bik ur_lico_bik, ur_lico.bank ur_lico_bank,
              ur_lico.attach ur_lico_attach, ur_lico.ur_address ur_lico_ur_address, ur_lico.address ur_lico_address,
              ur_lico.attach_pechat ur_lico_attach_pechat,ur_lico.gendir_podp ur_lico_gendir_podp, ur_lico.buh_podp ur_lico_buh_podp,
              ur_lico.gen_dir_f_in ur_lico_gen_dir_f_in, dogovor.number dogovor_number, 
              DATE_FORMAT(dogovor.registered, '%e %M %Y') dogovor_from, dogovor.registered dogovor_registered, dp.ur_lico_id
            FROM
              $user_table u 
              LEFT JOIN manager m ON (u.manager_id =m.id)
              JOIN docpack dp ON dp.$docpack_foreign_key = u.id
              LEFT JOIN dogovor  ON (dp.id=dogovor.docpack_id)
              LEFT JOIN tarif t ON (t.id = dp.tarif_id)
              LEFT JOIN blank_document b_dog ON (b_dog.id = t.blank_dogovor_id)
              LEFT JOIN ur_lico ON (ur_lico.id=dp.ur_lico_id)
            WHERE dp.id = ?
          },values=>[$id],onerow=>1);
          
      }


    }


    my $error_page='';
    $data->{firm}=~s{&}{&amp;}g; # OO не любит амперсанты в названии
    #check_old_rekvisits($type,$data);

    if($type eq 'dogovor'){
      $filename_prefix='dogovor_'.$data->{dogovor_number};
      $const->{template}=$data->{dogovor_blank};
      unless($data->{dogovor_blank}){
        $error_page=qq{
          Ошибка! в карточке <a href="/edit_form/tarif/$data->{tarif_id}" target="_blank">тарифа</a> не выбран бланк для договора!
        }
      }
    }
    elsif($type eq 'bill'){
      $filename_prefix='bill_'.$data->{bill_number};
      $filename_prefix=~s/\//-/g;
      $filename_prefix=~s/B/S/g;
      
      $const->{template}=$data->{bill_blank};
      if(!$data->{bill_blank}){
        $error_page=qq{Ошибка! в карточке <a href="/edit_form/tarif/$data->{tarif_id}" target="_blank">тарифа</a> не выбран бланк для счёта!}
      }

      unless(-f "$const->{template_path}/$const->{template}"){
        $error_page=qq{
          Ошибка! указанный в карточке <a href="/edit_form/tarif/$data->{tarif_id}" target="_blank">тарифа</a>
          бланк для счёта не найден на сервере<br/>
          директория: $const->{template_path}<br/>
          наименование файла: $const->{template}<br/>
        }
      }
    }
    elsif($type eq 'paid'){
      if($s->param('debug')){
        $s->print_header();
        #pre($data); exit;
      }
      $filename_prefix='paid_document_for_bill_'.$data->{act_number};
      if($s->{config}->{use_project} || -f './files/system/payment.odt'){
        $const->{template_path}='./files/system';
        $const->{template}='payment.odt';
      }
      else{

        $const->{template}=$db->get(
          select_fields=>'value',
          table=>'crm_const',
          where=>'name="payment"',
          onevalue=>1
        );        
      }

      unless($const->{template}){
        $error_page=qq{Бланк для платёжки не найден! загрузите его в константы системы или обратитесь к разработчику!<br>};

        
      }
    }
    elsif($type eq 'act'){
      $filename_prefix='Act_'.$data->{act_number};
      $const->{template}=$data->{act_blank};
    }
    elsif($type eq 'fact'){
      #print_header();
      #pre($data);
      #exit;
      $filename_prefix='SchetFactura_'.$data->{act_number};

      $const->{template}=$data->{fact_blank};
      #foreach my $v (qw()){

      #}
    }
    elsif($type eq 'av_fact'){
      $filename_prefix='Avansovaya_Sc-factura_'.$data->{act_number};
      unless($data->{fact_blank}){
        
        $s->print(qq{Не указан бланк счёта-фактуры для тарифа <b><a href="/edit_form.pl?config=tarif&action=edit&id=$data->{tarif_id}">$data->{tarif_name}</a></b>\n})->end;
      }
      $const->{template}=$data->{fact_blank};
    }
    else{
      $s->print('type не указан')->end;
      return;
    }

    if($error_page){
            $s->print(qq{
              <html>
                <head>
                  <style>body {margin: 100px; text-align: center;}</style>
                </head>
                <body>
                  <p>
                    $error_page
                    <a href='' onclick="history.back()">назад</a>
                  </p>
                </body>
              </html>
            })->end;
            return;
    }
    if($data->{registered}=~m/^(\d+)-(\d+)-(\d+)/){
      ($data->{from_d},$data->{from_m},$data->{from_y})=($3,get_mon_name($2),$1);
      $data->{registered_num}=qq{$3.$2.$1};
    }

    if($data->{act_registered}=~m/^(\d+)-(\d+)-(\d+)/){
      ($data->{from_d},$data->{from_m},$data->{from_y})=($3,get_mon_name($2),$1);
      $data->{act_registered_num}=qq{$3.$2.$1};
    }

    if($data->{dp_registered}=~m/^(\d+)-(\d+)-(\d+)/){
      my ($from_d,$from_m, $from_y)=($3,get_mon_name($2),$1);
      $data->{dp_registered}=qq{$3.$2.$1};
    }

    if($data->{paid_date}=~m/^(\d+)-(\d+)-(\d+)/){
      my ($from_d,$from_m, $from_y)=($3,get_mon_name($2),$1);
      $data->{paid_date}=qq{$3.$2.$1};
    }

    $data->{tarif_summ_prop}=first_to_big(rur_in_words($data->{tarif_summ}));
    $data->{bill_summ_with_nds_prop}=first_to_big(rur_in_words($data->{tarif_summ}));
    if($data->{act_summ}){
      $data->{act_summ_prop}=first_to_big(rur_in_words($data->{act_summ}));
    }



    if($format ne 'doc' && $format ne 'pdf'){
      $s->print('format не указан')->end;
      return ;
    }
    #print_header(); pre({ur_lico_attach=>{file=>'./files/ur_lico/'.$data->{ur_lico_attach}}}); exit;

    unless($data){
      $s->print('Не удалось обнаружить пакет документов для данного клиента!');
      return 
    }

    my $filename=$filename_prefix.'.'.$format;

    my $img={};
    {
      if($data->{ur_lico_attach}){
        $img->{ur_lico_signature}={file=>'./files/ur_lico/'.$data->{ur_lico_attach}};
      }

      if($data->{ur_lico_gendir_podp}){
        $img->{ur_lico_gendir_podp}={file=>'./files/ur_lico/'.$data->{ur_lico_gendir_podp}};
      }
      if($data->{ur_lico_buh_podp}){
        $img->{ur_lico_buh_podp}={file=>'./files/ur_lico/'.$data->{ur_lico_buh_podp}};
      }
      if($data->{ur_lico_attach_pechat}){
        $img->{ur_lico_attach_pechat}={file=>'./files/ur_lico/'.$data->{ur_lico_attach_pechat}};
        $img->{ur_lico_pechat}={file=>'./files/ur_lico/'.$data->{ur_lico_attach_pechat}};
      }
    }

    if($s->param('without_print')){
      $img={};
    }

    $filename=~s{\/}{-}g;
    unless($request_filename){ # для того, чтобы в браузере высвечивалось человеческое имя -- редректим
      my $qs='?'.$s->{vars}->{env}->{QUERY_STRING};
      $s->location('/backend/load_document/'.$filename.$qs)->end;
      return 
    }
    if($s->param('debug')){
      $s->pre({
        manager=>$s->{manager},
        const=>$const,
        data=>$data,
        img=>$img
      })->end;
      return ;
    }
    mkdir './tmp/'.$s->{manager}->{login};

    
    foreach my $k (keys %{$data}){
          Encode::_utf8_off($data->{$k});
    }
    
    my $tmp_dir;
    if($s->{config}->{use_project}){
      $tmp_dir='./tmp/project_'.$s->{project}->{id}.'__'.$s->{manager}->{login};
    }
    else{
      $tmp_dir='./tmp/'.$s->{manager}->{login};
    }
    odt_file2::odt_process( {
      's'=>$s,
      errors=>$errors,
      template            => $const->{template}, # шаблон, можно без пути если указан template_path
      template_path       => $const->{template_path}, # там лежат бланки шаблонов
      tmp_dir             => $tmp_dir,,
      format              => $format,
      upload_file_name    => $filename,
      vars => 
        {
          data=>$data,
          img=>$img   
        },
    } );
    print Dumper({
      tmp_dir=>$tmp_dir,
      manager=>$s->{manager},
      errors=>$errors}
    );
    if(scalar(@{$errors}) ) {
      $s->pre($errors)->end;
    }
    else{
      $s->{stream_out}=1;
    }
    
    
    #$s->print->end;
    #$par->{s}->{APP}->{HEADERS}

}


sub check_old_rekvisits{
  my $type=shift;
  my $data=shift;
  my $doc_registered='';
  return if($s->param('no_old'));
  if($type eq 'dogovor'){
    $doc_registered=$data->{dogovor_registered}
  }
  elsif($type=~m{^(paid|bill)$}){
    $doc_registered=$data->{bill_registered}
  }
  elsif($type=~m{^(av_fact|act|fact)$}){
    $doc_registered=$data->{act_registered}
  }


  # if($doc_registered=~m{[1-9]}){
  #   # проверяем, были ли какие-то другие реквизиты у организации в эту дату
  #   my $r=$db->query(
  #     query=>'
  #     SELECT * from ur_lico_old_owner where from_date<=? and to_date>=? and ur_lico_id=?',
  #     values=>[$doc_registered,$doc_registered,$data->{ur_lico_id}],
  #     onerow=>1
  #   );

  #   if($r){
  #     delete $r->{id};
  #     delete $r->{ur_lico_id};
  #     delete $r->{from_date};
  #     delete $r->{to_date};

  #     foreach my $k (keys(%{$r})){
  #       $data->{"ur_lico_$k"}=$r->{$k};
  #     }
  #   }
  #   #print_header();
    
  # }
}

sub get_mon_name{
  my $r={
    '01'=>'января',
    '02'=>'февраля',
    '03'=>'марта',
    '04'=>'апреля',
    '05'=>'мая',
    '06'=>'июня',
    '07'=>'июля',
    '08'=>'августа',
    '09'=>'сентября',
    '10'=>'октября',
    '11'=>'ноября',
    '12'=>'декабря',
  }->{$_[0]};


  return $r;
}

sub first_to_big{
    my $s=shift;
  
  {
    if($s=~m/^(.)/){
      my $f=$1;
      $f=~tr/абвгдеёжзийклмнопрстуфхцчшщьыъэюя/АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЬЫЪЭЮЯ/;
      
      $s=~s/^./$f/;
    }
  }
  
    return $s;
}
return 1;