class TranslationsController < ShikimoriController
  before_action :fetch_club
  before_action :set_breadcrumbs
  before_action :fetch_plans

  TRANSLATE_IGNORES = [19067,19157,21447,3447,3485,2448,1335,8648,1430,1412,1425,10029,597,1029,7711,1972,1382,10444,10370,10349,10359,10347,10324,10257,10015,10533,10499,10507,10444,10177,9441,7761,5032,7463,7723,6582,6604,5670,5973,5460,1367,1364,781,1506,1363,372,1430,3014,3016,6467,2448,1366,4985,283,10797,10802,10847,10997,11017,15865,15545,14631,10694,14947,15537,18469,18097,18357,18355,13029,13231,12979,9204,19291,10703,10531,12963,16287,17141,17497,17703,17969,18227,17705,19099,15069,17873,13207,14123,16347,17115,22099,22131,19645,23107,22197,22821,23555,23511,23285,23901,22465,23539,21639,21835,21671,23213,22735,23433,24403,24417,23737,24073,24071,28293,25383,22503,29868,29863]
  TRANSLATE_ME = [17389,26055,24893,28701,24227,16385,17080,28155,25689,27741,29093,28977,28423,27787,23847,19489,29325,25859,21439,28791,25649,25879,27411,27525,27631,27831,28999,30307,30344,30382,20815]

  def show
    @page_title = 'Аниме без описаний'

    @changes = TranslationsController.pending_animes

    @filtered_groups = @groups.map do |key,values|
      filtered = values.select do |anime|
        def anime.too_short?
          (ongoing? || anons? || latest?) && score > 7 && kind == 'TV' &&
            rating != 'G - All Ages' &&
            (description || '').size < 450 &&
            description != description_mal &&
            description != 'У этого аниме пока ещё нет описания.'
        end

        anime[:description].blank? || anime.too_short? || anime.description == anime.description_mal
      end

      [key, filtered]
    end.select {|k,v| v.any? }
  end

  # хеш со ждущими модерации аниме
  def self.pending_animes
    UserChange
      .where(status: UserChangeStatus::Pending)
      .where(model: Anime.name)
      .includes(:user)
      .each_with_object({}) {|v,memo| memo[v.item_id] = v }
  end

private
  # список аниме на перевод
  def fetch_plans
    @groups = {}

    @groups['Top 100 TV'] = Anime
      .where(id: Anime.where(kind: 'TV').where.not(ranked: 0).order(:ranked).limit(100). pluck(:id))
      .where.not(id: Anime::EXCLUDED_ONGOINGS)
      .where.not(id: TRANSLATE_IGNORES)
      .order(:ranked)

    @groups['Top 50 OVA'] = Anime
      .where(id: Anime.where("kind != 'TV' and kind != 'Movie'").where.not(ranked: 0).order(:ranked).limit(50).pluck(:id))
      .where.not(id: Anime::EXCLUDED_ONGOINGS)
      .where.not(id: TRANSLATE_IGNORES)
      .where.not(id: added_ids)
      .order(:ranked)

    @groups['Top 50 Movies'] = Anime
      .where(id: Anime.where(kind: 'Movie').where.not(ranked: 0).order(:ranked).limit(50).pluck(:id))
      .where.not(id: Anime::EXCLUDED_ONGOINGS)
      .where.not(id: TRANSLATE_IGNORES)
      .where.not(id: added_ids)
      .order(:ranked)

    @groups['Избранное модераторами'] = @club
      .animes
      .where.not(id: Anime::EXCLUDED_ONGOINGS)
      .where.not(id: TRANSLATE_IGNORES)
      .where.not(id: added_ids)
      .order(:ranked)

    @groups['Kara no Kyoukai'] = Anime
      .where("name ilike '%Kara no K%'")
      .where(censored: false)
      .order(:name)

    @groups['Ghost in the Shell'] = Anime
      .where("name ilike '%Ghost in the S%'")
      .where.not(id: TRANSLATE_IGNORES)
      .where('id < 10000')
      .where(censored: false)
      .order(:name)

    @groups['Break Blade'] = Anime
      .where("name ilike '%Break Bla%'")
      .where.not(id: TRANSLATE_IGNORES)
      .where(censored: false)
      .order(:name)

    @groups['Miyazaki Hayao'] = Person.find(1870)
      .animes
      .where('animes.id not in (?)', Anime::EXCLUDED_ONGOINGS)
      .where('animes.id not in (?)', TRANSLATE_IGNORES)
      .where('animes.kind != ?', 'Music')
      .where(censored: false)
      .order(:ranked)
      .limit(10)

    @groups['На первой странице жанра'] = Anime
      .where(id: [2835,2034,1729,3750,444,795,1569,1382,4188,540,268,4188,2559,11077,6904,666,2158,3907,1089,3665,85,401,2951,1092,813,6171,6811,535,1172,6793,60,5671,658,437,10083,4163,2951,8063,8634,5774,5719,741,5902,734,795,855,667,6331])
      .where.not(id: added_ids)
      .where(censored: false)
      .order(:ranked)

    @groups['Онгоинги'] = Anime
      .translatable
      .where(status: AniMangaStatus::Ongoing)
      .where('score != 0 and ranked != 0')
      .where.not(id: added_ids)
      .where.not(id: [10908,11385])
      .where.not(id: TRANSLATE_IGNORES)
      .where.not(rating: AniMangaQuery::Ratings['G'])
      .limit(15)

    @groups['Осень 2015'] = Anime
      .where(AniMangaSeason.query_for('fall_2015'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable

    @groups['Лето 2015'] = Anime
      .where(AniMangaSeason.query_for('summer_2015'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable

    @groups['Весна 2015'] = Anime
      .where(AniMangaSeason.query_for('spring_2015'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable

    @groups['Зима 2015'] = Anime
      .where(AniMangaSeason.query_for('winter_2015'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable

    @groups['Осень 2014'] = Anime
      .where(AniMangaSeason.query_for('fall_2014'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable

    @groups['Лето 2014'] = Anime
      .where(AniMangaSeason.query_for('summer_2014'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable

    @groups['Весна 2014'] = Anime
      .where(AniMangaSeason.query_for('spring_2014'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable

    @groups['Зима 2014'] = Anime
      .where(AniMangaSeason.query_for('winter_2014'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable

    @groups['Фильмы этого года'] = Anime
      .where(AniMangaSeason.query_for(DateTime.now.year.to_s))
      .where.not(id: Anime::EXCLUDED_ONGOINGS)
      .where.not(id: added_ids)
      .where('score >= 7.5 or status = ?', AniMangaStatus::Anons)
      .where.not(id: TRANSLATE_IGNORES)
      .where.not(rating: AniMangaQuery::Ratings['G'])
      .where(kind: 'Movie')
      .order(:ranked)
      .limit(45)

    @groups['Сериалы'] = Anime
      .where(id: AniMangaQuery::AnimeSerials)
      .where.not(id: Anime::EXCLUDED_ONGOINGS)
      .where.not(id: added_ids)
      .where.not(id: TRANSLATE_IGNORES)
      .order(:ranked)

    @groups['Сиквелы'] = Anime
      .where(id: [477,861,793,16,71,73,3667,5355,6213,4654,1519,889,2159,5342])
      .where.not(id: Anime::EXCLUDED_ONGOINGS)
      .where.not(id: added_ids)
      .where.not(id: TRANSLATE_IGNORES)
      .where(censored: false)
      .order(:ranked)

    @groups['Осень 2013'] = Anime
      .where(AniMangaSeason.query_for('fall_2013'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable
      .limit(30)

    @groups['Лето 2013'] = Anime
      .where(AniMangaSeason.query_for('summer_2013'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable
      .limit(30)

    @groups['Весна 2013'] = Anime
      .where(AniMangaSeason.query_for('spring_2013'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable
      .limit(30)

    @groups['Зима 2013'] = Anime
      .where(AniMangaSeason.query_for('winter_2013'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable
      .limit(30)

    @groups['Осень 2012'] = Anime
      .where(AniMangaSeason.query_for('fall_2012'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable
      .limit(30)

    @groups['Лето 2012'] = Anime
      .where(AniMangaSeason.query_for('summer_2012'))
      .where.not(id: added_ids)
      .where.not(id: [13409, 14093])
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable
      .limit(40)

    @groups['Весна 2012'] = Anime
      .where(AniMangaSeason.query_for('spring_2012'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable
      .limit(30)

    @groups['Зима 2012'] = Anime
      .where(AniMangaSeason.query_for('winter_2012'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable
      .limit(30)

    @groups['Осень 2011'] = Anime
      .where(AniMangaSeason.query_for('fall_2011'))
      .where.not(id: added_ids)
      .where.not(id: [11385])
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable
      .limit(30)

    @groups['Лето 2011'] = Anime
      .where(AniMangaSeason.query_for('summer_2011'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable
      .limit(30)

    @groups['Весна 2011'] = Anime
      .where(AniMangaSeason.query_for('spring_2011'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable
      .limit(25)

    @groups['Весна 2010'] = Anime
      .where(AniMangaSeason.query_for('fall_2010'))
      .where.not(id: added_ids)
      .where('score > 0 or ranked > 0')
      .where.not(id: TRANSLATE_IGNORES)
      .translatable
      .limit(18)

    @groups['Лето 2010'] = Anime
      .where(AniMangaSeason.query_for('summer_2010'))
      .where.not(id: added_ids)
      .where.not(id: TRANSLATE_IGNORES)
      .translatable
      .where.not(ranked: 0)
      .limit(10)

    @groups['Весна 2010'] = Anime
      .where(AniMangaSeason.query_for('spring_2010'))
      .where.not(id: added_ids)
      .where.not(id: TRANSLATE_IGNORES)
      .where('score > 0 or ranked > 0')
      .translatable
      .limit(10)

    @groups['Зима 2010'] = Anime
      .where(AniMangaSeason.query_for('winter_2010'))
      .where.not(id: added_ids)
      .where.not(id: TRANSLATE_IGNORES)
      .where('score > 0 or ranked > 0')
      .translatable
      .limit(9)

    @groups['Весна 2009'] = Anime
      .where(AniMangaSeason.query_for('fall_2009'))
      .where.not(id: added_ids)
      .where.not(id: TRANSLATE_IGNORES)
      .where('score > 0 or ranked > 0')
      .translatable
      .limit(12)

    @groups['Лето 2009'] = Anime
      .where(AniMangaSeason.query_for('summer_2009'))
      .where.not(id: added_ids)
      .where.not(id: TRANSLATE_IGNORES)
      .where('score > 0 or ranked > 0')
      .translatable
      .limit(12)

    @groups['Фильмы прошлых лет'] = Anime
      .where(AniMangaSeason.query_for("#{DateTime.now.year-3}_#{DateTime.now.year-1}"))
      .where.not(id: Anime::EXCLUDED_ONGOINGS)
      .where.not(id: added_ids)
      .where.not(rating: AniMangaQuery::Ratings['G'])
      .where('score >= 7.5')
      .where.not(id: TRANSLATE_IGNORES)
      .where(kind: 'Movie')
      .where(censored: false)
      .order(:ranked)
      .limit(45)

    @groups['В избранном у пользователей'] = Anime
      .where(id: FavouritesQuery.new.top_favourite_ids(Anime, 300))
      .where.not(id: added_ids)
      .where.not(kind: ['Special', 'Music'])
      .where(censored: false)
      .order(:ranked)

    @groups['Подборка фильмов'] = Anime
      .where(id: [5310,7222,1034,1824,1379,2594,6637,1089,9760,464,6372,570,974,8247,885,3089,597,31,3087,441,867,713,743,462,869,866,868,867,536,2889,6162,463,1192,4835,493,1686,465,2472,459,522,1815,442,460,461,155,4970,8246,4437,405,4246,2811,1829,936,9000,8115,21647])
      .where.not(id: added_ids)
      .order(:ranked)

    @groups['Подборка 9'] = Anime
      .where(id: [1576,5734,5702,6633,1520,690,1372,142,942])
      .where.not(id: added_ids)
      .where(censored: false)
      .order(:ranked)

    @groups['Подборка 8'] = Anime
      .where(id: [411,3701,1065,232,1485,85,3604,2112,407,1293,210,2829,4087,1808,3420,1483,880,455,323,1412,586,129,1454,593,364,2835,166,1852,2216,2409,1878,489,181,1589,11235,131,147,710,852,1250,5233,5984,798,1858,130,2204,696,1006,539,538,1147,541,540,1146,5504,1067,2460,1846,845,5675,4483,390,94,6758,173,1860,411,92,238,3322,1546,274,107,872,144,5041,52,2030,1397,3363,1576,2369,1086,3614,1602,2543,696,538,1133,539,5675,5420])
      .where.not(id: added_ids)
      .where(censored: false)
      .order(:ranked)

    @groups['Подборка 7'] = Anime
      .where(id: [3091,7711,1974,338,721,1914,1453,18,1486,395,384,9181,9617,123,872,306,133,32,5671,593,4087,166,5039,1860,2216,8937,4028,586,2594,634,3420,5005,3001,114,587,156,1690,4087,800,277,1592,2403,5060,11759,2162,417,4657,207])
      .where.not(id: added_ids)
      .where(censored: false)
      .order(:ranked)

    @groups['Подборка 6'] = Anime
      .where(id: [590,4719,4550,2924,6811,2508,106,5835,145,5958,4186,5150,200,2927,1965,3673,2012,940,3229,50,5597,4879,483,1013,341,198,4884,3467,195,3298,178,7088,1555,325,5079,3125,857,3927,2581,392,77,4192,967,1088,6046,5485,93,65,1719,1915,5074,132,67,26,389,209,165,2002,134,95,4038,3613,25,20,709,154,113,4581,5034,2683,953,878,5226,935,763,573,3731,334,68,4789])
      .where.not(id: added_ids)
      .where(censored: false)
      .order(:ranked)

    @groups['Подборка 5'] = Anime
      .where(id: [1498,3457,4752,150,270,27,1726,777,180,239,236,257,182,534,1164,1017,1045,3230,167,174,30,3588,329])
      .where.not(id: added_ids)
      .where(censored: false)
      .order(:ranked)

    @groups['Подборка 4'] = Anime
      .where(id: [1555,189,79,2476,4999,53,62,120,2993,248,3455,4214,3627,2595,291,4744,471,1222,846,4262,4063,259,177,969,569,251,1699,322,6201])
      .where.not(id: added_ids)
      .where(censored: false)
      .order(:ranked)

    @groups['Подборка 3'] = Anime
      .where(id: [43,387,227,1462,534,543,1002,6610,6164,4903,416,1172,535,2130,1738,1292,512,572,101,2787,5040,5682,6,2963,3225,5162,5713,256,47,237,856,169,153,59,2985,61,6676,343,33,3002,135,790,379,3594,5507,5525,1536,949])
      .where.not(id: added_ids)
      .where(censored: false)
      .order(:ranked)

    @groups['Подборка 2'] = Anime
      .where(id: [24,2104,355,1691,356,4654,1195,1840,3712,469,66,1887,2605,3228,6377,2104,158,3470,1579,2129,490,2986,1519,889,3572,1818,267,4725,400,2026,97,202,4106,1594,3713,228,98,99,76,7059,30,226,64,1827,2596])
      .where.not(id: added_ids)
      .where(censored: false)
      .order(:ranked)

    @groups['Подборка 1'] = Anime
      .where(id: AniMangaQuery::AnimeFeatured)
      .where.not(id: Anime::EXCLUDED_ONGOINGS)
      .where.not(id: added_ids)
      .where.not(id: TRANSLATE_IGNORES)
      .where(censored: false)
      .order(:ranked)

    @groups['Ai'] = Anime
      .where(id: [2238,149,553,3210,243,719,1020,3375,3656,1532,850,3750,1729,444,98,879,4535,1569,6203,143])
      .where.not(id: added_ids)
      .where(censored: false)
      .order(:ranked)
  end

  def added_ids
    @groups.flat_map {|k,v| v.map(&:id) }
  end

  def fetch_club
    @club = Group.find(2)
  end

  def set_breadcrumbs
    breadcrumb 'Клубы', clubs_url
    breadcrumb @club.name, club_url(@club)
  end
end
