var gulp        = require('gulp'),
    concat      = require('gulp-concat'),
    uglify      = require('gulp-uglify'),
    sourcemaps  = require('gulp-sourcemaps');

var src = [
  'scripts/roxen/roxen.js',
  'scripts/roxen/lib/lib.js',
  'scripts/roxen/lib/Math.uuid.js',
  'scripts/roxen/modules/config.js',
  'scripts/roxen/modules/afs.js',
  'scripts/roxen/run/run.js'
];

gulp.task('scripts', function () {
  return gulp.src(src)
    .pipe(sourcemaps.init())
    .pipe(uglify())
    .pipe(concat('roxen-all.min.js'))
    .pipe(sourcemaps.write('.'))
    .pipe(gulp.dest('scripts/'));
});

gulp.task('default', function() {
  gulp.start('scripts');
});
