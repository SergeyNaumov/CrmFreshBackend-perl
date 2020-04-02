use utf8;
use strict;
use Date::Parse qw/ str2time /;
use Data::Dumper;
#use Storable qw/dclone/; 
# для работы с полями
sub pre{
  my $v=shift;
  my $s=$Work::engine;
  #$Storable::Deparse=1;
  #$Storable::Eval=1;
  #my $to_log=dclone($v);
  push @{$s->{form}->{log}},Dumper($v);
}
sub remove_form_field{
    my %arg=@_;

  my $newlist;
  
  foreach my $f (@{$arg{form}->{fields}}){
    #print "555";
    push @{$newlist},$f if($f->{name} ne $arg{name});
  }

  $arg{form}->{fields}=$newlist;
}

sub select_managers_ids_from_perm{
  my $form=shift; my $perm=shift; my $s=$Work::engine;
  return [
        map {$_->{id} }
        @{
            $s->{db}->query(query=>select_from_table_perm($perm))
        }
  ];
}
sub select_managers_ids_from_perm{
  my $form=shift; my $perm=shift; my $s=$Work::engine;
  
  
  return [
    map {$_->{id} }
    @{
        $s->{db}->query(query=>select_from_table_perm($perm))
    }
];
}
sub select_from_table_perm{
  my $perm=shift; my $s=$Work::engine;
  my ($manager_table);
  if($s->{config}->{use_project}){
      return 'select '.
                'm.id,m.name '.
              'FROM '.
                'project_manager m '.
                'join project_manager_permissions mp ON (mp.manager_id=m.id) '.
                'join permissions_for_project p ON (p.id=mp.permissions_id) '.
              'WHERE m.project_id='.$s->{project}->{id}.q{ AND pname='}.$perm.q{' }.
              'UNION '.
              'select '.
                'm.id,m.name '.
              'FROM '.
                'project_manager m '.
                'join project_manager_group_permissions mgp ON (mgp.group_id=m.group_id) '.
                'join permissions_for_project p ON (p.id=mgp.permissions_id) '.
              'WHERE m.project_id='.$s->{project}->{id}.q{ AND pname='}.$perm.q{'}
  }
  else{
      return 'select '.
                'm.id,m.name '.
              'FROM '.
                'manager m '.
                'join manager_permissions mp ON (mp.manager_id=m.id) '.
                'join permissions p ON (p.id=mp.permissions_id) '.
              q{WHERE pname='}.$perm.q{' }.
              'UNION '.
              'select '.
                'm.id,m.name '.
              'FROM '.
                'manager m '.
                'join manager_group_permissions mgp ON (mgp.group_id=m.group_id) '.
                'join permissions p ON (p.id=mgp.permissions_id) '.
              q{WHERE pname='}.$perm.q{'}
  }


}

sub to_translit{
    ($_)=@_;
    Encode::_utf8_on($_);
    {
      
      use utf8
      #
      # Fonetic correct translit
      #
      s/Сх/Sh/; s/сх/sh/; s/СХ/SH/;
      s/Ш/Sh/g; s/ш/sh/g;

      s/Сцх/Sch/; s/сцх/sch/; s/СЦХ/SCH/;
      s/Щ/Sch/g; s/щ/sch/g;

      s/Цх/Ch/; s/цх/ch/; s/ЦХ/CH/;
      s/Ч/Ch/g; s/ч/ch/g;

      s/Йа/Ja/; s/йа/ja/; s/ЙА/JA/;
      s/Я/Ja/g; s/я/ja/g;

      s/Йо/Jo/; s/йо/jo/; s/ЙО/JO/;
      s/Ё/Jo/g; s/ё/jo/g;

      s/Йу/Ju/; s/йу/ju/; s/ЙУ/JU/;
      s/Ю/Ju/g; s/ю/ju/g;

      #s/Э/E\'/g; s/э/e\'/g;
      s/Э/E/g; s/э/e/g;
      s/Е/E/g; s/е/e/g;

      s/Зх/Zh/g; s/зх/zh/g; s/ЗХ/ZH/g;
      s/Ж/Zh/g; s/ж/zh/g;
      s/[ьЬъЪ]//g;
      tr/
      абвгдзийклмнопрстуфхцъыьАБВГДЗИЙКЛМНОПРСТУФХЦЪЫЬ/
      abvgdzijklmnoprstufhc\"y\'ABVGDZIJKLMNOPRSTUFHC\"Y\'/;
    };
    
    return $_;
}

sub cur_year{
  return (localtime(time))[5]+1900
}
sub next_date{
  my $d=shift;
  my ($mday,$mon,$year)=(localtime(str2time($d)+86400))[3,4,5];
  return sprintf("%04d-%02d-%02d",$year+1900,$mon+1,$mday);
}

sub cur_date{
  my $delta=shift;
  $delta=0 unless($delta);
  my ($mday,$mon,$year)=(localtime(time+86400*$delta))[3,4,5];
  return sprintf("%04d-%02d-%02d",$year+1900,$mon+1,$mday);
}

sub cur_time{
  my $delta_sec=shift;
  $delta_sec=0 unless($delta_sec);
  my ($sec,$min,$hour,$mday,$mon,$year)=(localtime(time()+$delta_sec))[0,1,2,3,4,5];
  return sprintf("%04d-%02d-%02d %02d:%02d:%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);
}
return 1;