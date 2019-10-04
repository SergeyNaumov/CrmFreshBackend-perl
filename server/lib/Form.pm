package Form;
=cut
Модуль для работы с формами
=cut
use utf8;
use strict;
use Exporter ();
use Data::Dumper;
our @ISA = "Exporter";
our @EXPORT    = qw();

sub new{
  my($class,%arg) = @_;
  my $self = bless {}, $class;
  my $opt=\%arg;
  foreach my $k (keys (%{$opt})){
    $self->{$k}=$arg{$k};
  }
  return $self;
}
sub check{
  my $form=shift;
  foreach my $f (@{$form->{fields}}){
    next if($f->{type} eq 'file');
    my $value=$form->{values}->{$f->{name}};
    
    if($f->{regexp} && $value!~/$f->{regexp}/){ # error regexp
      $f->{error}=1;
      print "err: $f->{name}: $value\n";
      $form->{error} = 1;
    }
    if($f->{unique} ){
      # Уникальность для модели
      if($form->{model} && $form->{model}->select(select_fields=>'count(*)',where=>$f->{name}.'=?',values=>[$f->{value}], onevalue=>1)){
        $form->{error}=1;
        $form->{error_unique}=1;
        $f->{error_unique}=1;
      }
      # уникальность для таблицы
      elsif($form->{table}){
        if($form->{connect}->get(
          select_fields=>'count(*)',
          table=>$form->{table},
          #debug=>1,
          where=>(
            ($form->{method} eq 'update')?(qq{$f->{name}=? AND $form->{table_id}<>$form->{id}}):qq{$f->{name}=?}),
          values=>[$value],
          onevalue=>1
        )){
          $form->{error}=1;
          $form->{error_unique}=1;
          $f->{error_unique}=1;
        }
      }
    }

  }
}
sub process{
  my $form=shift;
  my $s=$form->{engine}=$Work::engine;
  #print Dumper($s);
  my $values={};

  my $need_process=0;
  if($form->{json_send}){
    
    my $R=eval {$s->from_json($s->request_content())};
    
    if($R->{action} eq $form->{json_action_value}){
      $need_process=1;
      $form->get_values_json($R);
    }

  }
  elsif(!$form->{action_field} || ($s->param($form->{action_field}) eq $form->{action_field_value})){
    $need_process=1;
    $form->get_values_cgi();
  }

  if($need_process){
    $form->check();
    if(!$form->{error} && ref $form->{before_record_code} eq 'CODE'){
      &{$form->{before_record_code}}($form)
    }

    $form->check() if(!$form->{error});
    $form->{error}=1 if(exists($form->{error_list}) && scalar(@{$form->{error_list}}));

    if($form->{model} && !$form->{error}){ # запись в модель
      # before_record_code

      my $opt={};
      if($form->{record_method} eq 'replace'){
        $form->{model}->replace(data=>$form->{values});
      }
      elsif($form->{record_method} eq 'update'){
        $form->{model}->update(data=>$form->{values});
      }
      else{

        $form->{id}=$form->{model}->save(%{$form->{values}});
      }

      # after_record_code
      &{$form->{after_record_code}}($form) if(ref($form->{after_record_code}) eq 'CODE');
    }
    elsif($form->{table} && !$form->{error}){

      my %save_hash=(
        table=>$form->{table},
        data=>$form->{values}
      );

      my $where=''; my $vls;
      if($form->{record_method} eq 'replace' || $form->{record_method} eq 'update'){
        $save_hash{$form->{record_method}}=1;
        # Считываем старую запись для того, чтобы удалить старые файлы

        if(ref($form->{table_id}) eq 'ARRAY'){ # для работы с составными primary key
          my $i=0;
          foreach my $f (@{$form->{table_id}}){
            $where.=' AND ' if($where);

            if($form->{record_method} eq 'replace'){
              $where.=qq{$f=?};
              push @{$vls},$values->{$form->{$f}};
            }
            else{
             $where.=qq{$f='$form->{id}->[$i]'};
            }
            $i++;
          }
        }
        else{


          if($form->{record_method} eq 'replace'){
            $where=qq{$form->{table_id}=?};
            $vls=[$values->{$form->{table_id}}];
          }
          else{
            $where=qq{$form->{table_id}=$form->{id}};
          }
        }

        if($form->{table_id} && ($values->{$form->{table_id}} || $form->{id})){
          $form->{old_record}=$form->{connect}->get(table=>$form->{table},where=>$where,values=>$vls,onerow=>1);
        }
      }
      $save_hash{where}=$where if($where);

      if(scalar(%{$save_hash{data}}) && !$form->{error}){
        #$save_hash{debug}=1;
        $form->{id}=$form->{connect}->save(%save_hash);
        if($form->{record_method} ne 'update'){
          $form->{id}=$form->{values}->{$form->{table_id}};
          unless($form->{id}){
            $form->{id}=$form->{values}->{$form->{table_id}}
          }
        }
      }
    }

    if($form->{error}){
      my @errfld=();
      foreach my $f (@{$form->{fields}}){
        #push @errfld,$f->{name} if($f->{error});
        if($f->{error_unique}){
          push @{$form->{error_list}},qq{$f->{description} $f->{value} уже существует в системе}
        }
        elsif($f->{error}){
          push @{$form->{error_list}},qq{Поле $f->{description} не заполнено или заполнено не корректно}
        }
        
      }

      $form->{request_data}={
        success=>0,
        errors=>$form->{error_list},
        fields=>$form->{fields}
      };
      return join ',',@errfld;
    }
    else{

      # Загружаем файлы
      foreach my $f (@{$form->{fields}}){

        if($f->{type} eq 'file'){


          $f->{info}=$s->save_upload(
            var=>$f->{name},
            to=>$f->{filedir},
            resize=>$f->{resize}
          );

          # Удаляем старые файлы (Только тогда, когда мы имеем информацию о новом файле)
          if(my $filename=$form->{old_record}->{$f->{name}} && $f->{info}){
            if($filename=~m/^(.+)\.(.+)$/){

              my $filename_without_ext=$1;
              my $ext=$2;
              # 1. Удаляем сам файл
              #print qq{unlink("$f->{filedir}/$filename")\n};
              unlink("$f->{filedir}/$filename");

              # 2. Удаляем ресайзы
              foreach my $r (@{$f->{resize}}){
                my $resize_name=$r->{file};
                $resize_name=~s/\[\%ext\%\]/$ext/;
                $resize_name=~s/\[\%filename_without_ext\%\]/$filename_without_ext/;
                #print qq{unlink("$f->{filedir}/$resize_name");\n};
                unlink("$f->{filedir}/$resize_name");
              }
            }
          }

          #print qq{\n\n($form->{table} && $form->{table_id} && $form->{id} && ($form->{record_method} eq 'replace' || $form->{record_method} eq 'update' || $form->{record_method} eq 'insert'))\n\n};
          if(
            $f->{info}->{name} &&
            ($form->{table} && $form->{table_id} && $form->{id} && $form->{record_method} eq 'update') ||
            ($form->{table} && $form->{record_method} ne 'update')
          ){
            $form->{connect}->query(query=>"UPDATE $form->{table} SET $f->{name}=? WHERE $form->{table_id}=?",values=>[$f->{info}->{name},$form->{id}],debug=>$form->{debug});
          }

        }
      }

      # отправляем письма
      foreach my $ms (@{$form->{mail_send}}){
        # before_mail_sent
        &{$form->{before_mail_sent_code}}($form,$ms) if(ref $form->{before_mail_sent_code} eq 'CODE');
        foreach my $f (@{$form->{fields}}){
          $ms->{vars}->{$f->{name}}=$f->{value};
        }
        $ms->{vars}->{insert_id}=$form->{insert_id};
        foreach my $name (keys %{$ms->{vars}}){
          #$s->pre($name);
          $ms->{to}=~s/\[%$name%\]/$ms->{vars}->{$name}/g;
          $ms->{from}=~s/\[%$name%\]/$ms->{vars}->{$name}/g;
          $ms->{subject}=~s/\[%$name}%\]/$ms->{vars}->{$name}/g;
          $ms->{message}=~s/\[%$name%\]/$ms->{vars}->{$name}/g;
        }
        $s->send_mes(%{$ms});

        # after_mail_sent
        if(ref $form->{after_mail_sent_code} eq 'CODE'){
          &{$form->{after_mail_sent_code}}($form,$ms);
        }
      }
      $form->{request_data}={
        success=>1,
        error_list=>[]
      };
      return 1;
    }
  }
};


sub get_values_cgi{
  my $form=shift; my $s=$form->{engine}=$Work::engine;
  foreach my $f (@{$form->{fields}}){
    $f->{value}=$s->param($f->{name}) unless($f->{value});
    #$values->{$f->{name}}=$f->{value};
    next if($f->{type} eq 'file');
    #$form->{vls}->{$f->{name}}=$f->{value};
    $form->{values}->{$f->{name}}=$f->{value};
  }
}

sub get_values_json{
  my $form=shift;
  my $V=shift;
  foreach my $f (@{$form->{fields}}){
    $f->{value}=$V->{$f->{name}} unless($f->{value});
    $form->{values}->{$f->{name}}=$f->{value};
  }
}

return 1;
