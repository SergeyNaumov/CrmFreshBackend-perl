package CRM::Autocomplete;
use utf8;
use strict;
use Data::Dumper;

sub process{
    
    my %arg=@_;
    my $form=CRM::read_conf(%arg);
    my $s=$arg{'s'};

    my $list=[];
    my $R=$s->request_content(from_json=>1);
    my ($term,$name)=($R->{term},$R->{field_name});
    # проверить параметры, вывести ошибки
    my $sub_name;

    my $field;
    if($term){
        if($name=~m/^(.+)\.(.+)$/){
          ($name,$sub_name)=($1,$2);
        }
        

        if($sub_name){
            $field=$form->{fields_hash}->{$name};
            foreach my $f ( @{$field->{fields}} ){
                if($f->{name} eq $sub_name){
                    $field=$f;
                }
            }
        }
        else{
            $field=$form->{fields_hash}->{$name};
        }



    }
    else{
        push @{$form->{errors}},'не указан term'
    }

    if(!$field){
        push @{$form->{errors}},qq{field name: $name not found}
    }
    else{
        #print "get_list!!!\n";

        $list=get_list(
            name=>$name,
            form=>$form,
            element=>$field,
            value=>$term
            
        );
    }


    $s->print(
        $s->to_json({
            success=>scalar(@{$form->{errors}})?0:1,
            errors=>$form->{errors},
            list=>$list
        })
    )->end;
}
sub get_list{
    my %arg=@_;
    my $db=$arg{db};  my $form=$arg{form};
    my $element=$arg{element};
    my $work_table='';

    if($element->{before_search}){
        run_event(
            event=>$element->{before_search},
            description=>qq{$arg{name} before_search},
            form=>$form
        );
    }
    my $type=$element->{type_orig};
    #print Dumper($element);
    #print "type: $type\n";
    if($type eq 'filter_extend_text'){
        foreach my $x (@{$form->{QUERY_SEARCH_TABLES}}){
            if($x->{alias} eq $element->{filter_table}){
                $work_table=$x->{table};
                $element->{name}=$element->{db_name};
                $type='text';
                last;
            }
        }
    }
    
    # # multiconnect
    if($element->{type} eq 'multiconnect'){
        return $form->{db}->query(
            query=>qq{
                SELECT
                    $element->{relation_table_id} as id, $element->{relation_table_id} as value, $element->{relation_table_header} as label
                FROM
                    $element->{relation_table}
                WHERE
                    $element->{relation_table_header} like ?
                ORDER BY
                    $element->{relation_table_header}
                LIMIT  30
            },
            values=>['%'.$arg{value}.'%']
        );
    }

    if($type eq 'select_from_table' || $type eq 'filter_extend_select_from_table'){ #
        $element->{out_header}=$element->{header_field} unless($element->{out_header});
        my $select_fields=qq{$element->{value_field} v,$element->{out_header} d};
        $select_fields.=qq{, path} if($element->{tree_use});
        my $where=$element->{where};

        unless($element->{sphinx}->{server}){
            $where.=' AND 'if($where);
            $where.=qq{$element->{out_header} like "}.ecran_ind('%'.$arg{value}.'%').'"';
        }

        $where=' WHERE '.$where if($where);
        $element->{table} = $element->{filter_table} if($element->{type} eq 'filter_extend_select_from_table' && $element->{filter_table});
        
        if($element->{search_query}){
            my $like_val=ecran_ind($arg{value});
            $element->{search_query}=~s/(\?|<\%like\%>)/'\%$like_val\%'/gs;
            $element->{search_query}=~s/(\<\%v\%>)/$like_val/gs;
        }
        else{
            $element->{search_query}=qq{SELECT $select_fields from $element->{table} $where  ORDER by $element->{header_field} limit 30};
        }
        #print "sq: $element->{search_query}\n";
        return $form->{db}->query(
            query=>$element->{search_query}
        );

    }

}

sub ecran_ind{
  my $str=shift;
  $str=~s/@/\\@/gs;
  $str=~s/([\/\+\."'\(\)\+\*\-\=\[\]\!])/\\$1/gs;
  return $str;
}

return 1;