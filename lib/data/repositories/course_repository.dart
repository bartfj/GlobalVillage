import '../models/course.dart';

/// 课程查询仓库
class CourseRepository {
  final Course course;

  const CourseRepository(this.course);

  Lesson? lessonById(String lessonId) => course.lessonById(lessonId);

  List<Lesson> get orderedLessons => course.orderedLessons;
}
