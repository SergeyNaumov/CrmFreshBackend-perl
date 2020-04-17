package CRM::Session;
use strict;
use utf8;
sub project_create{ # создание сессии для проекта
    my %arg=@_; 

    my $s=$arg{s};
    my $form=$arg{form};
    my $R=$arg{R}; # json request data
    my $errors=[];

    
    if(!$arg{login}){
        $arg{login}=$R->{login};
        unless(defined($arg{login}) ){
            return 'При создании сессии (не указан login)'; return;
        }
    }
    
    if(!$arg{password}){
        $arg{password}=$R->{password};
        unless(defined($arg{password})){
            return 'При создании сессии (не указан password)'; return ;
        }   
    }
    


    # Таблица, по кот. будем проверять логин и пароль
    
    $arg{auth_id_field}='id' unless($arg{auth_id_field});
    $arg{auth_log_field}='login' unless($arg{auth_log_field});
    $arg{auth_pas_field}='password' unless($arg{auth_pas_field}); 
    #$arg{session_table}='session' unless($arg{session_table});    
    $arg{auth_table}='project_manager' unless($arg{auth_table});
    
    # 1. Узнаём идентификатор записи того, кто логинится:
    my $add_where='';
    if($arg{where}){
        $add_where=qq{ AND $arg{where}};
    }
    #use Data::Dumper;
    #print Dumper($s->{project});
    # проверяем, сколько было попыток зайти с данного логина
    if($arg{max_fails_login}=~m{^\d+$} && $arg{max_fails_login_interval}=~m{^\d+$}){
        my $fails=$arg{connect}->query(
            query=>'select count(*) from project_session_fails where project_id=? and  login=? and registered>=now() - interval ? second',
            values=>[$s->{project}->{id}, $arg{login},$arg{max_fails_login_interval}],
            onevalue=>1,
            errors=>$errors
        );
        
        if($fails>$arg{max_fails_login}){
            return 'Ошибка безопасности: превышено максимальное количество входа по логину';
            
        }
    }
    # проверяем, сколько было попыток зайти с данного ip под данным паролем
    if($arg{max_fails_ip}=~m{^\d+$} && $arg{max_fails_login_interval}=~m{^\d+$}){
        my $fails=$arg{connect}->query(
            query=>'select count(*) from project_session_fails where project_id=? and  ip=? and registered>=now() - interval ? second',
            values=>[$s->{project}->{id},$arg{ip},$arg{max_fails_ip_interval}],
            onevalue=>1,
            errors=>$errors
        );
        if($fails>$arg{max_fails_ip}){
            return 'Ошибка безопасности: превышено максимальное количество входа по IP';
            
        }
    }
    

    my $auth_id;
    if($arg{encrypt_method} eq 'mysql_encrypt'){ # пароль зашифрован с помощью функции encrypt
        $auth_id=$arg{connect}->query(
            query=>"SELECT $arg{auth_id_field} FROM project_manager WHERE project_id=? and $arg{auth_log_field}=? AND $arg{auth_pas_field}=ENCRYPT(?,password) $add_where",
            values=>[$s->{project}->{id},$arg{login}, $arg{password}],
            onevalue=>1
        );
    }
    else{
        $auth_id=$arg{connect}->query(
            query=>"SELECT $arg{auth_id_field} FROM project_manager project_id=? and WHERE $arg{auth_log_field}=? AND $arg{auth_pas_field}=? $add_where",
            values=>[$s->{project}->{id},$arg{login}, $arg{password}],
            onevalue=>1
        );
    }

    if($auth_id){ # залогинились
        $s->{manager}={
            id=>$auth_id,
            login=>$arg{login}
        };

        my $key=$s->gen_pas(200);

        # 4. Делаем запись в таблицу сессий
        $arg{connect}->save(
            table=>'project_session',
            data=>{
                project_id=>$s->{project}->{id},
                auth_id=>$auth_id,
                session_key=>$key,
                registered=>'func::now()',
            }
        );
        
        #print "SET cookie!\n";
        $s->set_cookie(name=>'auth_user_id',value=>$auth_id);
        $s->set_cookie(name=>'auth_key',value=>$key);
    }
    else{
        $arg{connect}->save(
            table=>'project_session_fails',
            data=>{
                project_id=>$s->{project}->{id},
                login=>$arg{login},
                registered=>'func::now()',
                ip=>$arg{ip}
            }
        );
        return 'авторизационные данные неверны';
    }
    return {
        errors=>$errors,
        success=>scalar(@{$errors})?0:1
    };
}
sub create{ # создание сессии
	my %arg=@_;

	my $s=$arg{s};
    my $form=$arg{form};
    my $R=$arg{R}; # json request data
    my $errors=[];

    
    if(!$arg{login}){
        $arg{login}=$R->{login};
        unless(defined($arg{login}) ){
            return 'При создании сессии (не указан login)'; return;
        }
    }
    
    if(!$arg{password}){
        $arg{password}=$R->{password};
        unless(defined($arg{password})){
            return 'При создании сессии (не указан password)'; return ;
        }   
    }


    # Таблица, по кот. будем проверять логин и пароль
    
    $arg{auth_id_field}='id' unless($arg{auth_id_field});
    $arg{auth_log_field}='login' unless($arg{auth_log_field});
    $arg{auth_pas_field}='password' unless($arg{auth_pas_field}); 
    $arg{session_table}='session' unless($arg{session_table});    
    $arg{auth_table}='manager' unless($arg{auth_table});    
    
    # 1. Узнаём идентификатор записи того, кто логинится:
    my $add_where='';
    if($arg{where}){
        $add_where=qq{ AND $arg{where}};
    }

    # проверяем, сколько было попыток зайти с данного логина
    if($arg{max_fails_login}=~m{^\d+$} && $arg{max_fails_login_interval}=~m{^\d+$}){
        my $fails=$arg{connect}->query(
            query=>'select count(*) from session_fails where login=? and registered>=now() - interval ? second',
            values=>[$arg{login},$arg{max_fails_login_interval}],
            onevalue=>1,
            errors=>$errors
        );
        
        if($fails>$arg{max_fails_login}){
            return 'Ошибка безопасности: превышено максимальное количество входа по логину';
            
        }
    }
    # проверяем, сколько было попыток зайти с данного ip под данным паролем
    if($arg{max_fails_ip}=~m{^\d+$} && $arg{max_fails_login_interval}=~m{^\d+$}){
        my $fails=$arg{connect}->query(
            query=>'select count(*) from session_fails where ip=? and registered>=now() - interval ? second',
            values=>[$arg{ip},$arg{max_fails_ip_interval}],
            onevalue=>1,
            errors=>$errors
        );
        if($fails>$arg{max_fails_ip}){
            return 'Ошибка безопасности: превышено максимальное количество входа по IP';
            
        }
    }
    

    my $auth_id;
    if($arg{encrypt_method} eq 'mysql_encrypt'){ # пароль зашифрован с помощью функции encrypt
        $auth_id=$arg{connect}->query(
            query=>"SELECT $arg{auth_id_field} FROM $arg{auth_table} WHERE $arg{auth_log_field}=? AND $arg{auth_pas_field}=ENCRYPT(?,password) $add_where",
            values=>[$arg{login}, $arg{password}],
            onevalue=>1
        );
    }
    else{
        $auth_id=$arg{connect}->query(
            query=>"SELECT $arg{auth_id_field} FROM $arg{auth_table} WHERE $arg{auth_log_field}=? AND $arg{auth_pas_field}=? $add_where",
            values=>[$arg{login}, $arg{password}],
            onevalue=>1
        );
    }
    #print "auth_id: $auth_id\n\n";
    if($auth_id){ # залогинились
        $s->{manager}={
            id=>$auth_id,
            login=>$arg{login}
        };

        my $key=$s->gen_pas(200);

        # 4. Делаем запись в таблицу сессий
        $arg{connect}->save(
            table=>$arg{session_table},
            data=>{
                auth_id=>$auth_id,
                session_key=>$key,
                registered=>'func::now()',
            }
        );
        
        #print "SET cookie!\n";
        $s->set_cookie(name=>'auth_user_id',value=>$auth_id);
        $s->set_cookie(name=>'auth_key',value=>$key);
    }
    else{
        $arg{connect}->save(
            table=>'session_fails',
            data=>{
                login=>$arg{login},
                registered=>'func::now()',
                ip=>$arg{ip}
            }
        );
        return 'авторизационные данные неверны';
    }
    return {
        errors=>$errors,
        success=>scalar(@{$errors})?0:1
    };
}


sub start{
    my %arg=@_;
    my $s=$arg{s};



    my $user_id=$s->get_cookie('auth_user_id');
    my $key=$s->get_cookie('auth_key');

    my $session_table=$s->{config}->{use_project}?'project_session':'session';
    my $manager_table=$s->{config}->{use_project}?'project_manager':'manager';

    my $errors=[];
    my $ok=$arg{connect}->query(
            query=>"SELECT count(*) FROM $session_table WHERE auth_id=? and session_key=?",
            values=>[$user_id, $key],
            onevalue=>1,
            errors=>$errors
    );

    if($ok){
        my $manager=$arg{connect}->query(query=>"select * from $manager_table where id=?",values=>[$user_id],onerow=>1,errors=>$errors);
        delete($manager->{password});
        $s->{manager}=$manager;
        unless($manager){
            $manager={login=>''}
        }
        $s->{manager}={login=>$manager->{login},id=>$manager->{id}};
        return {login=>$manager->{login},errors=>$errors};
    }
    return {login=>'',errors=>$errors};
}
sub logout{
    my %arg=@_;

    my $s=$arg{s}; 
    
    
    
    $arg{session_table}='session' unless($arg{session_table});
            
    my $user_id=$s->get_cookie('auth_user_id');
    my $key=$s->get_cookie('auth_key');

    if($user_id=~m/^\d+$/ && $key){
        if($s->{config}->{use_project}){
            $arg{connect}->query(query=>'DELETE FROM project_session WHERE auth_id=? and session_key=?',values=>[$user_id,$key]);
        }
        else{
            $arg{connect}->query(query=>'DELETE FROM session WHERE auth_id=? and session_key=?',values=>[$user_id,$key]);
        }
        
    }
    
}
return 1;