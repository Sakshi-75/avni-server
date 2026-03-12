package org.avni.server.web.request.syncAttribute;

import org.avni.server.domain.SubjectType;
import org.avni.server.service.ConceptService;
import org.junit.Test;
import java.util.Arrays;
import java.util.List;
import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class UserSyncAttributeAssignmentRequestTest {
    @Test
    public void testConstructorAndGetters() {
        SubjectType st1 = mock(SubjectType.class);
        SubjectType st2 = mock(SubjectType.class);
        ConceptService conceptService = mock(ConceptService.class);
        
        List<SubjectType> subjectTypes = Arrays.asList(st1, st2);
        UserSyncAttributeAssignmentRequest request = new UserSyncAttributeAssignmentRequest(
            subjectTypes, true, conceptService
        );
        
        assertNotNull(request.getSubjectTypes());
        assertTrue(request.isAnySubjectTypeSyncByLocation());
    }
    
    @Test
    public void testSetters() {
        SubjectType st = mock(SubjectType.class);
        ConceptService conceptService = mock(ConceptService.class);
        
        UserSyncAttributeAssignmentRequest request = new UserSyncAttributeAssignmentRequest(
            Arrays.asList(st), false, conceptService
        );
        
        request.setSubjectTypes(Arrays.asList());
        assertEquals(0, request.getSubjectTypes().size());
    }
}
