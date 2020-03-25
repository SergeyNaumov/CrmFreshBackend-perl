package Controller::Doc;
use CRM::LoadDocument;
use odt_file2;
use utf8;
sub get{
    # для каждого прокта это свой конфиг
    return [
        # CRM-стандартный документооборот
        {
            url=>'^\/load_document(\/(.+))?$',
            code=>sub{
              my $s=shift;
              
              CRM::LoadDocument::process($s,$1);
              $s->end;
            }
        },

        # водоучёт-сервис, скачать ДУ
        { 
            url=>'^\/DU\/load\/(\d+)\/.+$',
            code=>sub{

                my $s=shift; my $id=$1;
                # [%rtype%] [%zav_num%] [%grsi_num%]
                my $data=$s->{db}->query(
                    query=>q{
                        SELECT
                            w.*,r.header rheader, r.type rtype, r.method rmethod,
                            m.header master, md5(w.address) address_md5,
                            ae.hash address_hash, ae.temp, ae.vlajn, ae.davl,
                            mm.etalon_reg_num
                        from
                            work w
                            LEFT JOIN reestr_si r ON r.id=w.grsi_num
                            LEFT JOIN master m ON w.master_id=m.id
                            LEFT JOIN main_master mm ON (m.main_master_id=mm.id)
                            LEFT JOIN address_env ae ON (md5(w.address) = ae.hash)
                        where w.id=?
                    },
                    values=>[$id],
                    onerow=>1
                );
                if(!$data){
                    $s->print("Не найдена выполненая работа с id=$id")->end;
                    return

                }
                my $is_ok=$data->{is_ok};
                {
                    
                    #$data={}; # для отладки, чтобы не было лишнего
                    
                    my $dn=$data->{dn};

                    
                    # по одному адресу за одно число эти показатели должны быть одинаковые
                    unless($data->{address_hash}){
                        $data->{temp}=range(from=>21,to=>27,order=>1); # температура
                        $data->{vlajn}=range(from=>31,to=>48); # относительная влажность
                        $data->{davl}=range(from=>98,to=>102,order=>1); # атмосферное давление
                        $s->{db}->query(
                            query=>'REPLACE INTO address_env(hash,dat_pov,temp,vlajn,davl) values(?,?,?,?,?)',
                            values=>[$data->{address_md5},$data->{dat_pov},$data->{temp},$data->{vlajn},$data->{davl}],
                        );
                        #$s->pre("RECORD");
                    }

                    # Когда ГВС: 50-65
                    # Когда ХВС: 5-10
                    # !!!!!!!!!!!!!!!!!11
                    $data->{b3}=$data->{qmax}=51;
                    # ^^^^ исправить

                    $data->{b11}=$data->{b3}+range(from=>-1,to=>1,order=>1);

                    

                    $data->{c3}=range(from=>1.1,to=>1.7,order=>1); # 1,1 - 1,7 (случайное значение в этом интервале)
                    # !!! почему-то получился 1, проверить range

                    
                    $data->{d3}=sprintf("%04d", range(from=>1,to=>7000) ); # случайное от 0001 до 9948
                    

                    if($dn==15){
                        # 50..55
                        $data->{d4}=$data->{e3}=sprintf("%04d", $data->{d3}+range(from=>500,to=>550) );
                        $data->{d5}=$data->{e4}=sprintf("%04d", $data->{d4}+range(from=>500,to=>550) );
                        $data->{e5}=sprintf("%04d", $data->{d5}+range(from=>500,to=>550) );
                        $data->{g6}=0.132;
                    }
                    else{
                        # 60..65
                        $data->{d4}=$data->{e3}=sprintf("%04d", $data->{d3}+range(from=>600,to=>650) );
                        $data->{d5}=$data->{e4}=sprintf("%04d", $data->{d4}+range(from=>600,to=>650) );
                        $data->{e5}=sprintf("%04d", $data->{d5}+range(from=>600,to=>650) );
                        $data->{g6}=0.22;
                    }


                    

                    $data->{f3}=range(from=>-2,to=>2,order=>2); #-2..+2 c шагом 0.01
                    $data->{f4}=$data->{f3}+range(from=>-0.3,to=>0.3,order=>1); # F3 +/- 0.3 c шагом 0.01
                    $data->{f5}=$data->{f4}+range(from=>-0.3,to=>0.3,order=>1); # F3 +/- 0.3 c шагом 0.01

                    $data->{j6}=range(from=>-2,to=>2,order=>2); #-2..+2 c шагом 0.01
                    $data->{j7}=$data->{j6}+range(from=>-0.3,to=>0.3,order=>1);
                    $data->{j8}=$data->{j7}+range(from=>-0.3,to=>0.3,order=>1);

                    if($is_ok){ # если годен
                        $data->{n9}=range(from=>0.3,to=>5,order=>2); #от 0 до +5 с шагом 0.01
                    }
                    else{
                        $data->{n9}=range(from=>5.5,to=>10,order=>2);
                    }
                    
                    $data->{n10}=$data->{n9} + range(from=>-0.3,to=>0.3,order=>2); # +/- 0.3 от n9
                    $data->{n11}=$data->{10} + range(from=>-0.3,to=>0.3,order=>2); # +/- 0.3 от n10

                    $data->{h6}=$data->{e5}+range(from=>300,to=>500);


                    if($dn==15){
                        $data->{h7}=$data->{i6}=$data->{h6}+range(from=>500,to=>550);
                        $data->{h8}=$data->{i7}=$data->{h7}+range(from=>500,to=>550);
                        $data->{i8}=$data->{h8}+range(from=>500,to=>550);
                    }
                    else{ # dn=20
                        $data->{h7}=$data->{i6}=$data->{h6}+range(from=>600,to=>650);
                        $data->{h8}=$data->{i7}=$data->{h7}+range(from=>600,to=>650);
                        $data->{i8}=$data->{h8}+range(from=>600,to=>650);
                    }
                    # !!!!!(h6,i6...h6..i8) -- sprintf (4 знака)
                    # l9,m9 ...l11,m11
                    $data->{l9}=$data->{i8}+range(from=>50,to=>100);
                    # l10...l11 не заполняются, проверить!
                    if($dn==15){
                        $dala->{l10}=$data->{m9}=$data->{l9}+60;
                        $dala->{l11}=$data->{m10}=$data->{l10}+60;
                        $data->{m11}=$data->{l11}+60;
                    }
                    else{ # dn=20
                        $dala->{l10}=$data->{m9}=$data->{l9}+100;
                        $dala->{l11}=$data->{m10}=$data->{l10}+100;
                        $data->{m11}=$data->{l11}+100;
                    }

                    foreach my $i (6..8){
                        $data->{'h'.$i}=sprintf("%04d",$data->{'h'.$i});
                        $data->{'i'.$i}=sprintf("%04d",$data->{'i'.$i});
                    }

                    foreach my $i (9..11){
                        $data->{'l'.$i}=sprintf("%04d",$data->{'l'.$i});
                        $data->{'m'.$i}=sprintf("%04d",$data->{'m'.$i});
                    }

                    if($is_ok){
                        $data->{o8}=$data->{o9}=$data->{o10}='годен'
                    }
                    else{
                        $data->{o8}=$data->{o9}=$data->{o10}='не годен'
                    }
                }
                
                #return;
                $data->{num_full}="$data->{num_sv1}/$data->{num_sv2}/$data->{num_sv3}";
                if($data->{dat_pov}=~m/^(\d{4})-(\d{2})-(\d{2})$/){
                    $data->{dat_pov}="$3.$2.$1";
                }
                
                foreach my $k (keys %{$data}){
                      Encode::_utf8_off($data->{$k});
                }
                my $t='du1.odt';

                odt_file2::odt_process( {
                  's'=>$s,
                  template            => './files/vodserv/'.$t, # шаблон, можно без пути если указан template_path
                  #template_path       => $const->{template_path}, # там лежат бланки шаблонов
                  tmp_dir             => './tmp/'.$s->{manager}->{login},
                  format              => 'doc',
                  upload_file_name    => 'ДУ.doc',
                  vars => 
                    {
                      data=>$data,
                      img=>{}
                    },
                } );

                #$s->print('testdoc')->end;
            }
        }
    ]

    
}

sub range{
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
}

return 1;