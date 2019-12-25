$form={
  title => 'Статьи', # Наименование сущности в интерфейсе пользователя
  work_table => 'article', # Таблица в СУБД для хранения сущности
  work_table_id => 'id', # Primary key поле (должно быть числовым)
  make_delete => '1', # Разрешено ли удалять записи
  header_field=>'header',
  default_find_filter => 'header',
  events=>{ # Описание обработчика событий
    .....
  },
  
  fields =>
  [ # Набор полей
    
  ]
};
