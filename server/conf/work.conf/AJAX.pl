{
    calc_num_sv1=>sub{ # при выборе поверителя возвращаем его табельный номер
      my $s=shift;
      my $v=shift;

      if($v->{main_master_id} && $v->{main_master_id}=~m/^\d+$/){
        my $tnumber=$s->{db}->query(query=>'SELECT tnumber from main_master where id=?',values=>[$v->{main_master_id}],onevalue=>1);
        if($tnumber){
          return [
            'num_sv2',{value=>$tnumber}
          ]
        }
        else{
          return [
            'main_master_id',{error=>'проверьте справочник, не найден порядковый номер по журналу для данного поверителя'}
          ]
        }

      }
      else{
        return [
          'main_master_id',{error=>'выберите поверителя'}
        ]
      }
    },
    check_num_sv1=>sub{
      my $s=shift; my $v=shift;
      if($v->{num_sv1}!~m/^\d+$/){
        return [
          'num_sv1',{error=>'номер не указан или указан не корректно'}
        ]
      }
      elsif($v->{num_sv2}=~m/^\d{3}$/ &&  $v->{dat_pov}=~m/[1-9]/){
        
        my @where="(num_sv1=? and num_sv2=?  and dat_pov=?)";
        if($form->{id}){
          push @where,"(id <> $form->{id})"
        }
        
        my $exists_num=$s->{db}->query(
          query=>"select * from work WHERE ".join(' AND ',@where),
          values=>[$v->{num_sv1},$v->{num_sv2},$v->{dat_pov}],
          onerow=>1
        );
        if($exists_num){
          return [
            'num_sv1',{error=>qq{такой номер уже есть: <a href="/edit_form/work/$exists_num->{id}" target="_blank">здесь</a>}}
          ]
        }
        return [
          'num_label',{value=>"$v->{dat_pov}/$v->{num_sv2}/$v->{num_sv1}"},
          'num_sv1',{error=>''}
        ]
      }
      return [
        'num_sv1',{error=>''},

      ]
    },
    num_sv=>sub{ # вычисляем номер свидетельства
      #my $result_main=[];

      return $form->{run}->{ajax_num_sv}(@_);
      #return $result_main;

    },
    calc_dat_pov_next=>sub{
      my $s=shift; my $v=shift;
      my $result=$form->{run}->{ajax_num_sv}($s,$v);
      my $r2=$form->{run}->{ajax_dat_pov_next}($s,$v);
      if(scalar($r2)){
        push @{$result},@{$r2};
      }
      return $result;

      
    },
    master_id=>sub{
      my $s=shift; my $v=shift;
      my $result=[];
      if(!$v->{master_id}){
          push @{$result},(
              'master_id',{error=>'выберите мастера'}
          );
      }
      else{
          push @{$result},(
              'master_id',{error=>''}
          );
      }
      return $result;
    }
  }