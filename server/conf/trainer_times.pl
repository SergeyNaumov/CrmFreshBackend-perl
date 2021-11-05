$form={
    title=>'Расписание тренеров',
    work_table=>'manager',
    work_table_id=>'id',
    #start_date=>'2021-10-22',
    header_field=>'name',
    # получение списка объектов (за кем закрепляется засписание)
    #value -- id выбираемого
    #text -- метка
    #multi -- возможно поставить несколько за период
    multi=>1, # Возможно добавлять несколько  записей на одно время
    select_list_query=>q{
        SELECT
            m.id value, m.name text
        FROM
            manager m
            join manager_permissions mp ON mp.manager_id=m.id
        WHERE mp.permissions_id=1

    },
    # Получение расписания за период
    get_list_query=>q{

        SELECT
            tt.id id,tt.id as '_id',
            tt.manager_id fk,
            concat(wt.name,
                if(tt.group_workout=1,' (Г)', ' (И)')
            ) as `name`,
            if(tt.group_workout=0,1,0) multi,
            if(tt.group_workout=1,'green', '') as `color`,
            tt.interval_begin as `start`,
            tt.interval_end as `end`,
            tt.group_workout
        FROM
            trainer_times tt
            JOIN manager wt ON wt.id = tt.manager_id
        WHERE 
            (tt.interval_begin - interval 30 day) <= ? and 
            (tt.interval_begin + interval 30 day) >= ?
                    
    },
    # Собственная функция, определяющая занято время или нет
    time_busy=>sub{
        my %arg=@_;
        my $s=$arg{'s'}; my $times=$arg{times}; my $form=$arg{form};
        my $R=$arg{R};
        my $query;
        if($R->{fields_values} && $R->{fields_values}->{group_workout}){
            # Групповая тренеровка -- не допускается никаких тренеровок в это время
            $query=qq{SELECT count(*) from $form->{table} WHERE interval_begin>=? and interval_end<=?},
        }
        else{
            $query=qq{SELECT count(*) from $form->{table} WHERE interval_begin>=? and interval_end<=? and group_workout=1};
        }
        # индивидуальная тренеровка не допускается групповых тренеровок в это время
        return $s->{db}->query(
            query=>$query,
            values=>[$times->[0],$times->[1]],
            #debug=>1,
            onevalue=>1,
        );
        

        

    },
    colors_fill=>sub{
        my $events=shift;


        my $len1=scalar(@{$form->{colors}});
        my $len2=scalar(@{$form->{colors2}});

        foreach my $e (@{$events}){
            my $len=$len1;
            my $colors=$form->{colors};
            if(!$e->{group_workout}){ # для индивидуальныъ тренеровок свой набор цветов, а для групповых свой
                $colors=$form->{colors2};
                $len=$len2;
            }
            unless($e->{color}){
                $e->{color}=$colors->[$e->{fk} % $len];
            }
            
        }
    },
    # multi -- возможность добавлять ещё одну запись

    select_label=>'Выберите тренера',
    table=>'trainer_times',
    foreign_key=>'manager_id',
    interval_minutes=>60,
    interval_count=>12,
    first_interval=>9,
    read_only=>0,
    colors=>['#e8f5e9','#c8e6c9','#a5d6a7','#81c784','#66bb6a','#4caf50','#43a047','#388e3c','#2e7d32','#1b5e20'],
    # Пулл доп. цветов (для индивидуальных занятий)
    colors2=>['#e8eaf6','#c5cae9','#9fa8da','#7986cb','#5c6bc0','#3f51b5','#3949ab','#303f9f','#283593','#1a237e'],
    events=>{
        permissions=>sub{
            #$form->{read_only}=1
            #pre(5555)
        }
    },
    # Дополнительные поля
    fields=>[
        {
            description=>'Групповое занятие',
            type=>'checkbox',
            name=>'group_workout',
            multi=>0, # В том случае если выбран такой чекбокс -- добавлять несколько записей на одно время уже нельзя
        },

    ]
    # {
    #   description=>'Расписание',
    #   type=>'time_table',
    #   name=>'time_table',
    #   
    #   
    #   
    #   form_event_name=>'Добавить в расписание',
    #   table=>'trainer_times',
    #   foreign_key=>'trainer_id',
    #   header_field=>'name', # имя в work_table, соответствующее имени того, кто забронировал
    #   active_color=>'#4a30d7', # Цвет, которым отмечаются записи данной карты
    #   busy_color=>'#6f6d78', # цвет, которым отмечены занятые записи
    #   begin_date=>'2021-09-01', # Дата начала расписания
    #   end_date=>'2022-05-01', # Дата окончания расписания
    # }
}