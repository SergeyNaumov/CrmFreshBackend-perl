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

                my $data=$s->{db}->query(
                    query=>'SELECT * from work where id=?',
                    values=>[$id],
                    onerow=>1
                );
                if(!$data){
                    $s->print("Не найдена выполненая работа с id=$id")->end;
                    return

                }
                if($data->{is_ok}){
                    $data={}; # для отладки, чтобы не было лишнего
                    
                    my $dn=$data->{dn};

                    $data->{qmax}=51;
                    $data->{b11}=range(from=>-1,to=>1,order=>1);

                    

                    $data->{c3}=range(from=>1.1,to=>1.7,order=>1); # 1,1 - 1,7 (случайное значение в этом интервале)
                    
                    
                    $data->{d3}=sprintf("%04d", range(from=>1,to=>9948) ); # случайное от 0001 до 9948
                    

                    if($dn==15){
                        # 50..55
                        $data->{d4}=$data->{e3}=sprintf("%04d", $data->{d3}+range(from=>50,to=>55) );
                        $data->{d5}=$data->{e4}=sprintf("%04d", $data->{d4}+range(from=>50,to=>55) );
                        $data->{e5}=sprintf("%04d", $data->{d5}+range(from=>50,to=>55) );
                    }
                    else{
                        # 60..65
                        $data->{d4}=$data->{e3}=sprintf("%04d", $data->{d3}+range(from=>60,to=>65) );
                        $data->{d5}=$data->{e4}=sprintf("%04d", $data->{d4}+range(from=>60,to=>65) );
                        $data->{e5}=sprintf("%04d", $data->{d5}+range(from=>60,to=>65) );
                    }


                    

                    $data->{f3}=range(from=>-2,to=>2,order=>2); #-2..+2 c шагом 0.01
                    $data->{f4}=$data->{f3}+range(from=>-0.3,to=>0.3,order=>1); # F3 +/- 0.3 c шагом 0.01
                    $data->{f5}=$data->{f4}+range(from=>-0.3,to=>0.3,order=>1); # F3 +/- 0.3 c шагом 0.01

                    $data->{n9}=range(from=>0,to=>5,order=>2); #от 0 до +5 с шагом 0.01
                    $data->{n10}=$data->{n9} + range(from=>-0.3,to=>0.3,order=>2)."\n";; # +/- 0.3 от n9
                    $data->{n11}=$data->{10} + range(from=>-0.3,to=>0.3,order=>2)."\n";; # +/- 0.3 от n10

                    $data->{h6}=$data->{e5};

                    if($dn==15){

                    }


                }
                $s->pre($data)->end;
                return;
                
                my $t=$data->{is_ok}?'du1.odt':'du2.odt';
                # du2.odt -- не годен
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