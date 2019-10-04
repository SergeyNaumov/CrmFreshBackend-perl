$form=$::form;

sub permissions_go{ # доступ в карту

        
        tinymce_load_base64::init($form,'./files/task');
        if($form->{manager}->{permissions}->{make_add_task}){
            $form->{not_create}=0;
        }
        #pre($form->{manager});
        $form->{is_owner}=( # Права постановщика задачи
          $form->{manager}->{login}=~m{^(admin|naumov)$} || 
          $form->{old_values}->{fm__id} eq $form->{manager}->{id}
        ) ;
        $form->{is_admin}=(
          $form->{manager}->{login}=~m{^(admin|naumov)$}
        );

        $form->{make_delete}=1 if($form->{is_admin} || $form->{manager}->{permissions}->{make_del_task});
        
        if(!$form->{is_admin} && !$form->{manager}->{permissions}->{view_all_task}){ # показываем только свои задачи
          $form->{add_where}="( wt.from_task=$form->{manager}->{id} OR wt.to_task=$form->{manager}->{id} OR obs.manager_id=$form->{manager}->{id} )";
        }

        if($form->{id}){
          my $sth=$form->{dbh}->prepare(q{
            SELECT
              wt.*,
              fm.id fm__id, fm.name fm__name, fm.email fm__email, 
              tm.id tm__id, tm.name tm__name, tm.email tm__email
            FROM
              task wt
              LEFT JOIN manager fm ON (fm.id=wt.from_task)
              LEFT JOIN manager tm ON (tm.id=wt.to_task)
            WHERE wt.id=?
          });
          $sth->execute($form->{id});
          $form->{old_values}=$sth->fetchrow_hashref;
          $form->{title}=$form->{old_values}->{header};
          pre($form->{old_values});
        }

        #if(param('debug')){
        #  pre(&{$form->{run}->{get_to_addr}});
        #  exit;
        #}

}
sub get_link{
    return qq{https://crm.strateg.ru/edit_form.pl?config=task&action=edit&id=$form->{id}}
}

sub get_to_addr{
  my %to=();
  return '' unless($form->{id});
  foreach my $e (($form->{old_values}->{fm__email}, $form->{old_values}->{tm__email})){
    if($e=~m{@} && $e ne $form->{manager}->{email}){
      $to{$e}=1
    }
  }

  my $sth=$form->{dbh}->prepare("SELECT email from manager m join task_observe o ON (m.id=o.manager_id) where o.task_id=?");
  $sth->execute($form->{id});
  while(my $item=$sth->fetchrow_hashref){
    if($item->{email}=~m{@}){
      $to{$item->{email}}=1;
    }
  }

  return join(',',(keys %to));
};
sub html_links{
    my $v=shift;
    $v=~s{([^"'])(https?://[a-zA-Z0-9\._\/\?=&%-;]+)}{$1<a href="$2" target="_blank">$2</a>}gis;
    return $v
}

sub send_create_message{
    my %arg=@_;
    #pre(\%arg);
    my $sth=$form->{dbh}->prepare(q{
      SELECT
        p.header,
        m.email,
        p.owner
      FROM
        task_project p join manager m ON (m.id=p.owner)
      where p.id=?
    });
    $sth->execute($arg{project_id});
    my $project=$sth->fetchrow_hashref;
    my %to=('sv@digitalstrateg.ru'=>1);
    if($project->{email}){
      $to{$project->{email}}=1;
    }
    if($project->{owner}=~m{^\d+$}){
      $form->{dbh}->do("UPDATE task set to_task=$project->{owner} where id=$form->{id}");
    }

    if(scalar(keys %to)){
        my $link=&{$form->{run}->{get_link}};

        send_mes({
          from=>'no-reply@crm.strateg.ru',
          to=>join(',',keys(%to)),
          subject=>'Новая задача: '.$form->{new_values}->{header}.' | '.$project->{header},
          message=>qq{
            <p>Новая задача: <a href="$link">$form->{new_values}->{header}</a><br>
            <p>
              <b>Проект:</b> $project->{header}<br>
              <b>Постановщик:</b> $form->{manager}->{name}
            </p>
            <hr>
            
          }
        });
    }
}

sub get_run{
    return
    {


    }
}
return 1;