use utf8;
use strict;
sub read_conf{

  # read_conf(
  #   config=>$config,
  #   action=>$action,
  #   id=>$id,

  # )

    my %arg=@_;
    my $config=$arg{config}; my $s=$Work::engine;
    my $form;
    my $data=$s->template({dir=>'./conf',template=>'./conf/'.$config.'.pl'});
    
    eval($data);
    
    if($@){
        #$s->print($@.'<hr>');
        error_eval($@,$data,$s);
        return undef;
    }
    $form->{errors}=[] unless($form->{errors});
    create_fields_hash($form); # Routine
    
    # test_login='admin'
    $form->{action}=$arg{action} if($arg{action});
    $form->{script}=$arg{script};
    # script: admin_table, find_results, edit_form, memo, 1_to_m, 
    $form->{id}=$arg{id} if($arg{id}=~m{^\d+$});
    $form->{config}=$config;
    
    if( ($form->{script} eq 'admin_table' && $form->{action} eq 'edit') || 
      ($form->{script} eq 'memo' && $form->{acrtion} eq 'get_data') ||
      $form->{script} eq 'find_results'
    ){
      $form->{db}=$s->{connects}->{crm_read};
      $form->{dbh}=$form->{db}->{connect};
    }
    else{
      $form->{db}=$s->{connects}->{crm_write};
      $form->{dbh}=$form->{db}->{connect};
    }
    

    
    $form->{work_table}=$config if(!$form->{work_table});
    $form->{work_table_id}='id' if(!$form->{work_table_id});
    
    $form->{manager}=get_permissions_for(
      login=>get_cur_role(
        login=>$s->{login},
        config=>$config,
        's'=>$s
      )
    );
    #push @{$form->{errors}},$form->{manager}->{login};
#    print "login: $form->{manager}->{login}\n";
    $form->{self}=$s;
    
    set_default_attributes($form); # Routine
    
    if($form->{script} eq 'edit_form'){
      $form->{new_values}=$arg{values} if($form->{action}=~m/^(update|insert)$/);
      
    }
    
    #if($form->{id}){
      $form->{values}=get_values_form(form=>$form,'s'=>$s);
    #}
    
    
    run_event(event=>$form->{events}->{permissions},description=>'events.permissions',form=>$form);
    foreach my $f (@{$form->{fields}}){
      if(exists($f->{permissions}) && ref($f->{permissions}) eq 'CODE'){
        run_event(event=>$f->{permissions},description=>'permissions for field:'.$f->{name},form=>$form);
      }
    }

    return $form;

}
sub get_permissions_for{
    my %arg=@_; my $s=$Work::engine;
    my $connect=$s->{db};
    my $manager=$connect->query(query=>q{
      SELECT 
        m.*,
        if(m.id = ow.id,1,0) is_owner,
        mg.path group_path,
        concat_ws('/',mg.path,mg.id) full_group_path
      FROM
        manager m
        LEFT JOIN manager_group mg ON (m.group_id = mg.id)
        LEFT JOIN manager ow ON (mg.owner_id = ow.id) 
      WHERE m.login = ?},values=>[$arg{login}],onerow=>1,log=>$arg{form}->{log});

    delete $manager->{password};
    # Собираем права менеджера:
    my $permissions_list=
     $connect->query(
      query=>q{SELECT p.id, p.pname from permissions p, manager_permissions mp where p.id = mp.permissions_id and mp.manager_id = ?},
      values=>[$manager->{id}]
    );
    $manager->{permissions}={};
    foreach my $p (@{$permissions_list}){
      $manager->{permissions}->{$p->{pname}}=$p->{id};
    }

    # права группы, в которой непосредственно нахдится менеджер также ему присваиваются
    if($manager->{group_id}){
        my $gr_perm_list=$connect->query(
          query=>q{
              SELECT
                p.id, p.pname
              from
                permissions p, manager_group_permissions mgp
              where
                p.id = mgp.permissions_id and mgp.group_id = ?
          },
          values=>[$manager->{group_id}]
        );

        foreach my $p (@{$gr_perm_list}){
          $manager->{permissions}->{$p->{pname}}=$p->{id};
        }
    }

    # Для каждого пользователя можно разделить свою файловую директорию
    $manager->{files_dir}='./files';
    $manager->{files_dir_web}='/files';

    #print Dumper($manager);
    # права оптимизатора
    # my $opt_perm_list=$connect->query(
    #   query=>q{
    #     SELECT
    #       p.id, p.pname
    #     from
    #       optimization_permissions p, manager_optimization_permissions mp
    #     where
    #       p.id = mp.permissions_id and mp.manager_id = ?
    #   },values=>[$manager->{id}]
    # );
    # foreach my $p (@{$opt_perm_list}){
    #   $manager->{optimize_permissions}->{$p->{pname}}=$p->{id};
    # }
    return $manager;
}
sub get_cur_role {
  my %arg=@_;
  if($arg{config} eq 'manager'){ # в инструменте manager роли орининальные
    return $arg{login};
  }
  my $r=$arg{'s'}->{db}->query(
    query=>q{
      SELECT
        m2.login
      FROM
        manager m
        JOIN manager_role mr ON (m.id = mr.manager_id)
        JOIN manager m2  ON (m2.id = mr.role AND m.current_role = m2.id)
      WHERE m.login=?
    },
    values=>[$arg{login}],
    onevalue=>1
  );
  return ($r?$r:$arg{login})
}
return 1;