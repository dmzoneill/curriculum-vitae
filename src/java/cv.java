// import java.util.*;
// import java.io.File;
// import com.fasterxml.jackson.databind.*;
// import com.fasterxml.jackson.dataformat.yaml.*;

// public class cv {

//     public static void main(String[] args) {

//         try{
//         System.out.println("Hello, World!");

//         String cv_file = System.getenv("cv_file");
//         String template_file = System.getenv("template_file");
//         String output_file = System.getenv("output_file");

//         System.out.println( "CV file" );
//         System.out.println( cv_file );
//         File file = new File(cv_file);
//         // ObjectMapper objectMapper = new ObjectMapper(new YAMLFactory());

//         ObjectMapper mapper = new ObjectMapper(new YAMLFactory());
//         mapper.findAndRegisterModules();
//         YamlMap ym2 = mapper.readValue(file, YamlMap.class);

//         System.out.println( "Start keys" );
//         for ( String key : ym2.mp.keySet() ) {
//             System.out.println( key );
//         }
//         System.out.println( "End keys" );

//         // ApplicationConfig config = objectMapper.readValue(file, ApplicationConfig.class);
//         // System.out.println("Application config info " + config.toString());
//         } catch(Exception exception) {
//             System.out.println( exception.toString() );
//         }
//     }
// }