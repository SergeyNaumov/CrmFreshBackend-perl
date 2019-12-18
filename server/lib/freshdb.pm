package freshdb;
use DBI;
use utf8;
use strict;
use Data::Dumper;
# хак для Data::Dumper + utf8
$Data::Dumper::Useqq = 1;
{ no warnings 'redefine';
    sub Data::Dumper::qquote {
        my $s = shift;
        return "'$s'";
    }
}
sub new{
  my($class,$arg) = @_;
  my $self = bless {}, $class;
  foreach my $k (keys(%{$arg})){
    $self->{$k}=$arg->{$k};
  }
  if(!$arg->{is_sphinx} && !$arg->{dbname}){
      print Dumper($arg);
      die('not dbname param');
  }
  $self->{connect}=DBI->connect("DBI:mysql:$arg->{dbname}:$arg->{host}",$arg->{user},$arg->{password},
    {
      Warn => 1,
#      PrintWarn => 1,
#      PrintError => 1,
      AutoCommit => 1,
      mysql_enable_utf8 => 1,
      on_connect_do => ["SET names utf8"],
      mysql_auto_reconnect=>1,
      RaiseError => 1
    }
  );  # {  }
  $self->{connect}->{'mysql_enable_utf8'} = 1;

  $self->{connect}->do("SET names utf8");
  $self->{connect}->{mysql_auto_reconnect} = 1;

  unless($arg->{is_sphinx}){
    $self->{connect}->do("SET lc_time_names = 'ru_RU'");
    #$self->{connect}->do("SET names $arg->{charset}") if($arg->{charset});
  }

  return $self;
}

sub repair{ # восстанавливает соединение
  my $self=shift;
  my $err=1; my $list;
  my $max_loop=5; my $i=1;
  while($err){
      eval(q{
        $sth=$self->{connect}->prepare("show status like 'uptime'");
        $sth->execute();
        $list=$sth->fetchall_arrayref({});
      });
      $err=$@;
      #print Dumper({db=>$db,n=>$n,list=>$list,err=>$@});
      if($err || !scalar(@{$list})){ # восстанавливаем соединение
        #print "Repair connect: $self->{dbname}\n";
        #print Dumper($db);
        $self->{connect}=DBI->connect("DBI:mysql:$self->{dbname}:$self->{host}",$self->{user},$self->{password},
            {
              Warn => 1,
              PrintWarn => 1,
              PrintError => 1,
              AutoCommit => 1,
              mysql_enable_utf8 => 1,
              on_connect_do => ["SET names utf8"],
              mysql_auto_reconnect=>1,
              RaiseError => 0
            }
          );  # {  }
          $self->{connect}->do('set names utf8');
          $self->{connect}->{'mysql_enable_utf8'} = 1;
          $self->{connect}->do(q{SET lc_time_names = 'ru_RU'}) unless($self->{is_sphinx});
      }
    $i++;
    last if($i>$max_loop);
  }


  $self->{connect}->{mysql_auto_reconnect} = 1;

  unless($self->{is_sphinx}){

    $self->{connect}->do("SET lc_time_names = 'ru_RU'");
    #$self->{connect}->do("SET names $arg->{charset}") if($arg->{charset});
  }
}

sub get{
  my ($self,%args)=@_;
  my $opt=\%args;

  #$opt->{connect}=$self->{connect} unless($opt->{connect});
  #print "$self->{connect}, connect; $opt->{connect}\n";
  if($self->{model_method} eq 'conf' && $self->{confdir} && $opt->{struct} && !$opt->{table_id}){
    unless(-e qq{$self->{confdir}/$opt->{struct}}){
      die "file '$self->{confdir}/$opt->{struct}' not found\n";
    }
    $self->{form}=&get_form_from_conf(qq{$self->{confdir}/$opt->{struct}});
    $opt->{table_id} = $self->{form}->{work_table_id};
    $opt->{table} = $self->{form}->{work_table};
    if($opt->{use_model} && !$opt->{select_fields}){
      $opt->{table}.=' wt';
      my @sf=("wt.$opt->{table_id} id"); # select_fields massive
      my $tnumber=1;

      foreach my $field (@{$self->{form}->{fields}}){
          if($field->{type} eq 'file'){
            my $fd=$field->{filedir};
            $fd=~s/^\.\.\//\//;
            push @sf, qq{concat('$fd/',wt.$field->{name}) as $field->{name}_and_path};
            my $i=1;
            while($field->{converter}=~m/output_file=['"](.+?)['"]/gs){
              my $out=$1;
              next if ($out eq '[%input%].[%input_ext%]');
              $out=~s/\.\[%input_ext%\]/\[%input_ext%\]/;
              $out=~s/(\]|^)([^\[]+)\[/$1,'$2',\[/;

              $out=~s/\[%input%\]/substring_index(wt.$field->{name},'.',1)/;
              $out=~s/\[%input_ext%\]/'\.',substring_index(wt.$field->{name},'.',-1)/;
              push @sf, qq{concat('$fd/',$out) as $field->{name}_and_path_mini$i};
              $i++;
            }
          }
          elsif($field->{type} eq 'select_values'){
              my $case='';
              $case.=qq{, CASE $field->{name} };
              while($field->{values}=~m/([^;]+?)=>([^;]+)/gs){
                $case.=qq{WHEN '$1' then '$2' }
              }
              $case.=qq{ END as `$field->{name}`};
              push @sf, $case;
          }
          elsif($field->{type} eq 'select_from_table'){
            my $alias=qq{t$tnumber};

            $opt->{table}.=qq{ LEFT JOIN $field->{table} $alias ON (wt.$field->{name} = $alias.$field->{value_field})};
            push @sf, qq{$alias.$field->{header_field} $field->{name},  $alias.$field->{value_field} $field->{name}_value};
            $tnumber++;
          }
          elsif($field->{type} eq 'text' || $field->{type} eq 'textarea' || $field->{type} eq 'checkbox'){
            push @sf, qq{wt.$field->{name}};
          }
      }
      $opt->{select_fields} = join(', ',@sf);
      #print "sf: $opt->{select_fields}";

    }

  }
  else{

    $opt->{table_id} = 'id' if(!$opt->{table_id});
  }
  $opt->{select_fields}='*' unless($opt->{select_fields});
  my $table=$opt->{table} if($opt->{table});
  if($opt->{id}=~m/^\d+$/){
    $table=$opt->{where}='id = '.$opt->{id};
    $opt->{onerow}=1 unless($opt->{onevalue})
  }

  if($opt->{perpage}=~m/^\d+$/){ # С УЧЁТОМ РАССТРАНИЧИВАНИЯ
      my $page=$opt->{page}?$opt->{page}:$Work::engine->{vars}->{TMPL_VARS}->{page};
      my $query_count="SELECT CEILING(count(*) / $opt->{perpage}) FROM $opt->{table}";
      $query_count.=qq{ WHERE $opt->{where}} if($opt->{where});
      $query_count.=qq{ GROUP BY $opt->{group}} if($opt->{group});
      my $sth=$self->{connect}->prepare($query_count);
      $sth->execute(@{$opt->{values}});
      $Work::engine->{vars}->{TMPL_VARS}->{maxpage}=$sth->fetchrow();
      my $limit1=($page-1)*($opt->{perpage});
      $opt->{limit}=qq{$limit1,$opt->{perpage}};
  }

  my $query="SELECT $opt->{select_fields} FROM $opt->{table}";
  $query.=qq{ WHERE $opt->{where}} if($opt->{where});
  $query.=qq{ GROUP BY $opt->{group}} if($opt->{group});
  $query.=qq{ ORDER BY $opt->{order}} if($opt->{order});
  $query.=qq{ LIMIT $opt->{limit}} if($opt->{limit}=~m/^\d+(,\d+)?$/);

  if($opt->{debug}){
    if($opt->{log}){
      push @{$opt->{log}},"QUERY:\n$query\n";
      push @{$opt->{log}},"VALUES:\n$opt->{values}\n";
      #Dumper($opt->{values});
    }
    else{
      print "QUERY:\n$query\n".Dumper($opt->{values});
    }
    
  }
  my $result;
  my $sth;

  eval(q{
    $sth=$self->{connect}->prepare($query);
    $sth->execute(@{$opt->{values}});
  });

  if($@){
    my $err="Error_query:\n$query\n".Dumper($opt->{values}).";\nerror: $@";
    if($opt->{errors}){
      push @{$opt->{errors}},$err;
      return undef;
    }
    else{
      print $err; 
    }
    

  }
  if($opt->{onevalue}){
    $result=$sth->fetchrow();

  }
  elsif($opt->{get_hash}){
    $result=$sth->fetchall_hashref($opt->{get_hash})
  }
  elsif($opt->{onerow}){
    $result=$sth->fetchrow_hashref();
    if($opt->{to_html}){
      $result=$Work::engine->to_html($result)
    }
    #print Dumper($result);
  }
  else{
    $result=$sth->fetchall_arrayref({});
    # get -> tree_use
    if($opt->{tree_use} && ($opt->{depth}<$opt->{max_depth} || !defined $opt->{max_depth})){
        if(defined $opt->{depth}){
          $opt->{depth}++;
        }
        else{
          $opt->{depth}=1 unless defined($opt->{depth});
        }
        if($opt->{massive}){
          my @new_res=();
          foreach my $id (@{$result}){
            $opt->{where}=~s/(([\S]+\.)?parent_id)(\s*=\s*|\s+is\s+[^\s]+)/$1=$id/is;
            my %optx=%{$opt};
            @new_res=(@new_res,$self->get(%optx));
          }
          @{$result}=($result,@new_res);
        }
        else{
          if($opt->{tree_to_massive}){
            my @new_res=();
            foreach my $r (@{$result}){
              $opt->{where}=~s/(([\S]+\.)?parent_id)(\s*=\s*|\s+is\s+[^\s]+)/$1=$r->{id}/is;
              my $nr = $self->query(%{$opt});
              @new_res=(@new_res,@{$self->query(%{$opt})});
            }
            #print Dumper(@new_res);
            @{$result}=(@{$result},@new_res);
          }
          else{

            foreach my $r (@{$result}){

              $opt->{where}=~s/(([\S]+\.)?parent_id)(\s*=\s*\d+|\s+is\s+[^\s]+)/$1=$r->{id}/is;

              $r->{child}=$self->get(%{$opt});
            }
          }
        }
    }
  }
  # тут сделать замену кавычек и символов <> на html
  if($opt->{safe_xss}){
    $result=safe_xss($result);
  }


  if($opt->{to_json}){
    $result=$Work::engine->to_json($result);
  }

  if($opt->{to_tmpl}){
     $Work::engine->to_tmpl($opt->{to_tmpl},$result);
  }

  if(defined $opt->{maxpage}){
    return $opt->{maxpage};
  }
  else{
    return $result;
  }
}

#sub to_tmpl{
# my $var=shift;
# my $value=shift;
#}

sub query{

  my ($self,%arg)=@_;
  my $opt=\%arg;
  if($opt->{debug}){
    my $d=Dumper($opt);
    if($opt->{log}){
      push @{$opt->{log}},$d
    }
    else{
      print "$d\n";
    }
    
  }

  if($opt->{values} && !ref($opt->{values})){
    $opt->{values}=[$opt->{values}];
  }

  my $sth;
  $self->{connect}->do('set names utf8');
  my $reply_cnt=0;
  while(1){
    eval {
      $sth=$self->{connect}->prepare($opt->{query});
      $sth->execute(@{$opt->{values}});
    };

    if($DBI::errstr){ # если запрос отработал криво 
      if($reply_cnt>3){ # более 3-х раз -- выходим
        if($opt->{errors}){
          push @{$opt->{errors}},'Error query:'.Dumper({query=>$opt->{query},values=>$opt->{values}}) ;
          push @{$opt->{errors}},qq{Error query: $DBI::errstr};
        }
        else{
          print "\nError query:".Dumper({query=>$opt->{query},values=>$opt->{values}});
          #print "\nError query:\n\t$DBI::errstr\n\n";
        }
        return;

        
        #exit;
      }
      else{ # повторяем 
        $reply_cnt++;
      }
    }
    else{ # выходим
      last;
    }
  }


  my $res;
  if($opt->{query}=~m/^\s*(desc|select)\s/is){
    if($opt->{onevalue}){
      $res=$sth->fetchrow();
    }
    elsif($opt->{onerow}){
      $res=$sth->fetchrow_hashref();
    }
    elsif($opt->{massive}){

      my @a=();
      while(my $item=$sth->fetchrow_hashref()){
          my $k=(keys(%{$item}))[0]; push @a,$item->{$k};
      }
      $res=\@a;

    }
    elsif($opt->{get_hash}){
      $res=$sth->fetchall_hashref($opt->{get_hash})
    }
    elsif($opt->{hash}){
      my %h=();
      while(my $item=$sth->fetchrow_hashref()){
          my $k=(keys(%{$item}))[0]; $h{$item->{$k}}=1;
      }
      $res=\%h;
    }
    else{
      $res=$sth->fetchall_arrayref({});
    }
    $sth->finish();

    # TREE USE
    if($opt->{tree_use} && ($opt->{depth}<$opt->{max_depth} || !defined $opt->{max_depth})){
      if(defined $opt->{depth}){
        $opt->{depth}++;
      }
      else{
        $opt->{depth}=1 unless defined($opt->{depth});
      }
      if($opt->{massive}){
        my @new_res=();
        foreach my $id (@{$res}){
          $opt->{query}=~s/(([\S]+\.)?parent_id)(\s*=\s*|\s+is\s+[^\s]+)/$1=$id/is;
          my %optx=%{$opt};
          @new_res=(@new_res,$self->query(%optx));
        }
        @{$res}=($res,@new_res);
      }
      else{
        if($opt->{tree_to_massive}){
          my @new_res=();
          foreach my $r (@{$res}){
            $opt->{query}=~s/(([\S]+\.)?parent_id)(\s*=\s*|\s+is\s+[^\s]+)/$1=$r->{id}/is;
            my $nr = $self->query(%{$opt});
            @new_res=(@new_res,@{$self->query(%{$opt})});
          }
          #print Dumper(@new_res);
          @{$res}=(@{$res},@new_res);
        }
        else{

          foreach my $r (@{$res}){

            $opt->{query}=~s/(([\S]+\.)?parent_id)(\s*=\s*\d+|\s+is\s+[^\s]+)/$1=$r->{id}/is;
            #$::fresh->pre({
            #  query=>$opt->{query},
            #  r=>$r
            #});
            $r->{child}=$self->query(%{$opt});
          }
          #$::fresh->pre($res);
          #exit;
        }
      }
    }
    if($opt->{safe_xss}){

      $res=safe_xss($res);
    }

    if($opt->{to_json}){
      $res= $Work::engine->to_json($res);
    }
    if($opt->{to_tmpl}){
      if($opt->{depth}>1){
        return $res
      }
       $Work::engine->to_tmpl($opt->{to_tmpl},$res);
    }
    else{
      return $res;
    }
  }

}


sub save{
  my ($self,%args)=@_;
  my $opt=\%args;
  #print Dumper(\%args);
  $opt->{connect}=$self->{connect};
  $opt->{table} if($opt->{table});
  my $dumpdata=undef;
  my $sth=$self->{connect}->prepare("desc $opt->{table}");
  $sth->execute();
  my @fields=(); my @values_fn=(); my @values_exec=();
  #print Dumper($opt->{data});
  my $table_fields=$sth->fetchall_arrayref({});
  my $exists_field={};
  foreach my $desc (@{$table_fields}){
    next if($desc->{Key} eq 'auto_increment');
    my $field=lc($desc->{Field});
    $exists_field->{lc($field)}=1;
    foreach my $field_data (keys(%{$opt->{data}})){
      if($field eq lc($field_data)){
        #print "$field / $opt->{data}->{$field_data}\n";
        my $value=$opt->{data}->{$field_data};
        next unless(defined($value));
        if($opt->{update}){
          if($value=~m/^func::(.+)/){
            push @fields,qq{`$desc->{Field}`=$1};
            push @{$dumpdata},{$desc->{Field}=>$1};
          }
          else{
            push @fields,qq{`$desc->{Field}`=?};
            push @values_exec,$value;
            push @{$dumpdata},{$desc->{Field}=>$value};
          }
        }
        else{

          push @fields,$desc->{Field};
          if($value=~m/^func::(.+)/){
            push @values_fn,$1;
            push @{$dumpdata},{$desc->{Field}=>$1};
          }
          else{
            push @values_fn,'?';
            push @values_exec,$value;
            push @{$dumpdata},{$desc->{Field}=>$value};
          }
        }
      }
    }
  }
  #use Data::Dumper; print Dumper({exists_field=>$exists_field});
  if($opt->{errors}){
    foreach my $name (keys(%{$opt->{data}})){
      if(!$exists_field->{lc($name)}){
        #print "В базе данных отсутствует поле: $name\n";
        push @{$opt->{errors}},"В базе данных отсутствует поле: $name";
      }
    }
  }


  my $command; my $query;
  if($opt->{update} && $opt->{where}){
    $query="UPDATE $opt->{table} SET ".join(', ',@fields)." WHERE $opt->{where}";
  }
  else
  {
    if($opt->{on_replace} || $opt->{replace}){
      $command='REPLACE';
    }
    else{
      $command='INSERT';
    }
    if($opt->{ignore}){
      $command.=' IGNORE'
    }
    $query="$command INTO $opt->{table}(".join(',',@fields).") VALUES(".join(',',@values_fn).")";
  }

  if(ref($opt->{values}) eq 'ARRAY'){
    @values_exec=(@values_exec,@{$opt->{values}});
  }
  
  if($opt->{debug}){

    print "QUERY:\n$query\n".Dumper($dumpdata)."\n";
  }
  eval q{
    $sth=$self->{connect}->prepare($query);
    $sth->execute(@values_exec);
  };

  if($@){
    if($opt->{errors}){
      push @{$opt->{errors}},"Error_query:\n$query\n".Dumper(@values_exec)."\n$@";
    }
    else{
      die("Error_query:\n$query\n".Dumper(@values_exec)."\n$@")
    }
    
  }

  if(!$opt->{update} && !$opt->{replace}){
    return $sth->{mysql_insertid}
  }
  return undef;

}

sub safe_xss{
  my $t=shift;
  if(ref($t) eq 'HASH'){
    foreach my $k (keys(%{$t})){
      $t->{$k}=safe_xss($t->{$k});
    }
  }
  elsif(ref($t) eq 'ARRAY'){
    my $i=0;
    foreach my $e (@{$t}){
      $t->[$i]=safe_xss($e);
      $i++;
    }
  }
  else{
    $t=~s/>/&gt;/gs;
    $t=~s/</&lt;/gs;
    $t=~s/&/&amp;/gs;
    $t=~s/"/&quot;/gs;
    $t=~s/'/&apos;/gs;
  }
  return $t;
}

return 1;
