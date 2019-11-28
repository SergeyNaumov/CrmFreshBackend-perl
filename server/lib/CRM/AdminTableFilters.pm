use strict;
use utf8;
sub get_filters{
    my $s=shift; my $config=shift;
    my $request={};
    #print "config: $config\n";
    my $full_path='./conf/'.$config.'.pl';
    if(-f $full_path){
        
        my $form=read_conf(config=>$config, script=>'admin_table');
        return unless($form);
        create_fields_hash($form);
        my $filters=[];
        my $order=1;
        foreach my $f (@{$form->{fields}}){ # собираем фильтры
          if(ref($f->{before_code}) eq 'CODE'){
            run_event(event=>$f->{before_code},description=>'before_code for '.$f->{name},form=>$form,arg=>$f);
          }
          next if($f->{type}=~m{^(password|code|1_to_m|hidden)$} || !$f->{description});


          if($f->{type}=~m{filter_extend_text|textarea}){
            $f->{type}='text' 
          }
          elsif($f->{type}=~m{^(filter_extend_)?select_values$}){
            $f->{type}='select';
          }
          elsif($f->{type}=~m{^(filter_extend_)?date$}){
            $f->{type}='date';

          }
          elsif($f->{type}=~m/^(filter_extend_)?select_from_table$/){
              $f->{type}='select';
              $f->{header_field}='header' unless($f->{header_field});
              $f->{value_field}='id' unless($f->{value_field});
              $f->{values}=get_values_for_select_from_table($f,$form);
          }
          elsif($f->{type} eq 'memo'){
            #push @{$form->{log}},qq{SELECT $f->{auth_id_field} v, $f->{auth_name_field} d from $f->{auth_table} ORDER BY $f->{auth_name_field}};
            $f->{users}=$form->{db}->query(
              query=>qq{SELECT $f->{auth_id_field} v, $f->{auth_name_field} d from $f->{auth_table} ORDER BY $f->{auth_name_field}},
              errors=>$form->{log}
            );
          }

          # для фильтра с типом date у нас всё время range по умолчанию
          if($f->{type}=~m/^(date|time|datetime|daymon|yearmon)$/ && !defined($f->{filter_type})){ 
            $f->{range}=1
          }

          if($f->{filter_type} eq 'range'){
            $f->{range}=1
          }

          foreach my $k ( keys %{$f}){
            if(ref $f->{$k} eq 'CODE'){
              delete $f->{$k}
            }
          }
          foreach my $k (qw(tablename db_name regexp tab table where table_id header_field value_field filter_type empty_value)){
            delete $f->{$k}
          }
          if($f->{filter_on}){
            $f->{order}=$order; $order++;
          }
          push @{$filters},$f;
        }

        #$s->pre($form->{})
        if(exists($form->{filters_groups}) && ref($form->{filters_groups}) eq 'ARRAY' && scalar(@{$form->{filters_groups}}) ){
          foreach my $fg (@{$form->{filters_groups}}){
            $fg->{on}=0 if(!$fg->{on});
            $fg->{child}=[] if(!$fg->{child});

            if($fg->{filter_list} && ref($fg->{filter_list}) eq 'ARRAY'){
                foreach my $name (@{$fg->{filter_list}}){
                  my $i=0;
                  foreach my $f (@{$filters}){
                    if($f->{name} eq $name){
                      push @{$fg->{child}},$i;
                    }
                    $i++;
                  }
                  #if(my $f=$form->{fields_hash}->{$name}){
                  #  push @{$fg->{child}},$f
                  #}
                }
            }
          }
          #$filters=[];
        }
        
        $request={
            success=>1,            
            title=>$form->{title},
            filters=>get_clean_json($filters),
            search_links=>exists($form->{search_links})?$form->{search_links}:[],
            before_filters_html=>exists($form->{before_filters_html})?$form->{before_filters_html}:[],
            javascript=>exists($form->{javascript}->{admin_table})?$form->{javascript}->{admin_table}:'',
            filters_groups=>exists($form->{filters_groups})?$form->{filters_groups}:[],
            log=>$form->{log},
            permissions=>{
              make_create=>(!defined $form->{make_create} || $form->{make_create})?1:0,
              make_delete=>(!defined $form->{make_create} || $form->{make_create})?1:0,
              not_edit=>$form->{not_edit}?1:0
            },
            search_on_load=>$form->{search_on_load}?1:0,
            errors=>$form->{errors}
        };
    }
    else{
        $request={
            success=>0,
            errors=>['Конфиг '.$config.' не найден']
        };
    }
    $s->print(
        $s->to_json($request)
    )->end;
}

return 1;