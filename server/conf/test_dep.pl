=create table
CREATE TABLE `test_dep` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `dep1` varchar(20) DEFAULT NULL,
  `dep2` varchar(20) DEFAULT NULL,
  `dep3` tinyint(1) NOT NULL DEFAULT '0',
  `dep4` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
=cut
$form={
    title=>'Возможности CRM',
    #explain=>1,
    engine=>'mysql-strong', # default mysql
    default_find_filter=>'header',
    cols=>[
        [
            {description=>'Блок1',name=>'dep1'},
            {description=>'Блок2',name=>'dep2'},
        ],
        [
            
            {description=>'Блок3',name=>'dep3'},
            {description=>'Блок4',name=>'dep4'},
        ]
    ],
    fields=>[ 
        # Зависимые поля
        {
            description=>'Поле, от которого зависят другие поля',
            type=>'select_values',
            name=>'dep1',
            values=>[
                {v=>1,d=>'скрыть dep2, dep3 и dep4'},
                {v=>2,d=>'показать второй select'},
                {v=>3,d=>'показать второй select, а также текстовые поля'},
                {v=>4,d=>'заполнить рандомно текстовые поля'},
                {v=>5,d=>'скрыть все вкладки кроме этой'},
                {v=>6,d=>'показать описание'},
            ],
            frontend=>{
                fields_dependence=>q{[%INCLUDE './conf/test_dep.conf/dep1.js'%]}, # изменяем поведение других полей
                tabs_dependence=>q{} # изменяем поведение табов
            },
            before_html=>q{
                <div id="dep1_before_html" style="display: none;">
                    <p>Иногда требуется сделать так, чтобы в зависимости от выбранного значения в одном поле, изменялось поведение других полей.</p>
                    <p>Например, если это опросник, при выборе отсутствие подходящего варианта, можно предложить указать свой (сделать так, чтобы появилось некое поле для ввода текста).</p>
                    <p>Могут понадобится варианты посложнее</p>
                </div>
            },
            tab=>'dep1'
        },
        {
            description=>'dep2',
            name=>'dep2',
            type=>'select_values',
            values=>[
                {v=>1,d=>'Значение1'},
                {v=>2,d=>'Значение2'},
                {v=>3,d=>'Значение3'},
            ],
            tab=>'dep2'
            
        },
        {
            description=>'Текстовое поле!',
            tab=>'dependences',
            type=>'textarea',
            name=>'dep3',
            tab=>'dep3',
            frontend=>{
                after_buttons=>[
                    {description=>'кнопка1',js=>qq{[%INCLIDE './conf/test_dep.conf/dep3-button1.js'%]}},
                    {description=>'кнопка2',js=>qq{[%INCLIDE './conf/test_dep.conf/dep3-button2.js'%]}},
                    {description=>'кнопка3',js=>qq{[%INCLIDE './conf/test_dep.conf/dep3-button3.js'%]}},
                ]
            }
            # after_html=>q{
            #     <script>
            #         function dep3_autofill(){
            #             console.log('dep3 autofill');
            #         }
            #     </script>
            #     <a href="" onclick="dep3_autofill(); return false;">заполнить поле автоматически</a>
            # }
        },
        {
            description=>'Текстовое поле1',
            tab=>'dependences',
            type=>'textarea',
            name=>'dep4',
            tab=>'dep4'
        },
        # / Зависимые поля
       
    ]
};