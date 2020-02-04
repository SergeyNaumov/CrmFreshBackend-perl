package CRM::Wysiwyg;
use utf8;
use strict;
use Data::Dumper;
sub process{
  my %arg=@_;
  my $s=$arg{s};
  my $action='';
  my $errors=[];
  my $path;
  my $R={};
  if($arg{action} eq 'upload'){
    $action=$arg{action};
    $path=$s->param('path');
  }
  else{
    $R=$s->request_content(from_json=>1);
    $action=$R->{action};
    $path=$R->{path};
  }
  
  if(!$action){
    push @{$errors},'не передан параметр action'
  }
  #print "action: $action\n";

  my $form=CRM::read_conf(config=>$arg{config},script=>$arg{script},action=>$action,id=>$arg{id});
  

  my $file_list=[];
  #print "path: $path\n";
  check_path($path,$errors);
  unless(scalar(@{$errors})){
          if($action eq 'file_list'){
            $file_list=get_file_list('s'=>$s, path=>$path,errors=>$errors,form=>$form);
            $s->print_json({
                success=>scalar(@{$errors})?0:1,
                errors=>$errors,
                file_list=>$file_list,
                files_dir_web=>$form->{manager}->{files_dir_web}
            })->end;
          }
          elsif($action eq 'upload'){
            my $uploads=[];
            unless(scalar(@{$errors})){
                $uploads=$s->save_upload(
                    var=>'file',
                    to=>$form->{manager}->{files_dir}.$path,
                    multi=>1,
                    original=>1
                );
            }

            # загрузка файлов в wysiwyg-редакторе
            $file_list=get_file_list('s'=>$s, path=>$path,errors=>$errors,form=>$form);

            $s->print_json({
                success=>scalar(@{$errors})?0:1,
                file_list=>$file_list,
                errors=>$errors
            })->end;
          }
          elsif($action eq 'delete'){
            my $name=$R->{name};

            if(!$name){
                push @{$errors},'не указан параметр name';
            }
            elsif($name!~m/^\.\./ && $name!~m/\//){ # не содержит слешей и две точки в начале имени
                unlink($form->{manager}->{files_dir}.$path.$name);
            }
            else{
                push @{$errors},qq{параметр name не корректный: $name};
            }
            $file_list=get_file_list('s'=>$s, path=>$path,errors=>$errors,form=>$form);
            $s->print_json({
                success=>scalar(@{$errors})?0:1,
                errors=>$errors,
                file_list=>$file_list,
                files_dir_web=>$form->{manager}->{files_dir_web}
            })->end;
          }
  }
  else{
            $s->print_json({
                success=>scalar(@{$errors})?0:1,
                errors=>$errors
            })->end;
  }





}
sub check_path{
    my $path=shift; my $errors=shift;
    unless($path =~m{^\/} && $path=~m{^(\/[^\/]*)*\/$}){
        push @{$errors},'Wrong parametr path!';
    }
}
sub get_file_list{
    my %arg=@_; 
    return if(scalar( @{ $arg{errors} } ) );

    my $path=$arg{path};  my $form=$arg{form};
    if($path =~m{^\/} && $path=~m{^(\/[^\/]*)*\/$}){
        return $arg{s}->readdir($form->{manager}->{files_dir}.$path);    
    }
    else{
        push @{$arg{errors}},'Wrong parametr path!';
    }

}
return 1;